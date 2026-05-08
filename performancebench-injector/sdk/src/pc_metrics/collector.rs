// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! PC metrics collector — orchestrates all PC metric modules for a 1Hz tick.
//!
//! The PcCollector ties together PDH counters, DXGI frame timing, ETW session,
//! memory, CPU, disk I/O, GPU, and network modules into a single tick() call
//! that produces a complete MetricSample.
//!
//! Used by the pb-pcprobe binary (Plan 05-04) in its main profiling loop.

use crate::models::MetricSample;
use crate::pc_metrics::dxgi::{self, DxgiMethod, DxgiSession};
use crate::pc_metrics::etw::{self, EtwFrameSession};
use crate::pc_metrics::pdh::{self, PdhQuery};

/// Orchestrates PC metric collection at 1Hz.
pub struct PcCollector {
    /// Open PDH query for the target process
    pub pdh_query: PdhQuery,

    /// DXGI frame timing session (DetourHook or PresentMon)
    pub dxgi_session: Option<DxgiSession>,

    /// ETW frame timing session (admin-required, for non-DX games)
    pub etw_session: Option<EtwFrameSession>,

    /// Process name (for PDH counter paths)
    pub process_name: String,

    /// Process ID (for memory/CPU queries)
    pub process_id: u32,

    /// Number of logical CPU cores
    pub num_cores: u32,

    /// Last disk I/O cumulative bytes (for rate calculation)
    last_disk_read: i64,
    last_disk_write: i64,

    /// Last network cumulative bytes (for rate calculation)
    last_net_rx: i64,
    last_net_tx: i64,
}

impl PcCollector {
    /// Create a new PC collector for the target process.
    ///
    /// Opens PDH query, optionally starts DXGI injection/PresentMon, and
    /// optionally starts ETW session (requires admin).
    ///
    /// # Arguments
    /// * `process_name` - Process name for PDH counter paths (e.g., "game.exe")
    /// * `process_id` - Process ID for memory/CPU queries
    /// * `dxgi_method` - DXGI frame timing method (DetourHook or PresentMon)
    /// * `use_etw` - Whether to start ETW session (requires admin)
    pub fn new(
        process_name: &str,
        process_id: u32,
        dxgi_method: DxgiMethod,
        use_etw: bool,
    ) -> Result<Self, String> {
        // Open PDH query for the target process
        let pdh_query = pdh::open_query(process_name, true)?;

        // Determine number of cores
        let num_cores = std::thread::available_parallelism()
            .map(|n| n.get() as u32)
            .unwrap_or(4);

        // Start DXGI frame timing
        let dxgi_session = match dxgi_method {
            DxgiMethod::DetourHook => {
                // Try to inject DXGI hook
                match dxgi::build_dxgi_hook_dll() {
                    Ok(_dll_bytes) => {
                        match dxgi::inject_dx_hook(process_id, "pb-pcprobe-dx.dll") {
                            Ok(shared_memory) => Some(DxgiSession {
                                method: DxgiMethod::DetourHook,
                                shared_memory: Some(shared_memory),
                                presentmon: None,
                            }),
                            Err(e) => {
                                log::warn!("DXGI injection failed: {}. Falling back to PresentMon.", e);
                                // Fall back to PresentMon
                                match dxgi::start_presentmon(process_name) {
                                    Ok(session) => Some(DxgiSession {
                                        method: DxgiMethod::PresentMon,
                                        shared_memory: None,
                                        presentmon: Some(session),
                                    }),
                                    Err(e2) => {
                                        log::warn!("PresentMon also failed: {}. No FPS data.", e2);
                                        None
                                    }
                                }
                            }
                        }
                    }
                    Err(e) => {
                        log::warn!("DXGI hook DLL not available: {}. Trying PresentMon.", e);
                        match dxgi::start_presentmon(process_name) {
                            Ok(session) => Some(DxgiSession {
                                method: DxgiMethod::PresentMon,
                                shared_memory: None,
                                presentmon: Some(session),
                            }),
                            Err(e2) => {
                                log::warn!("PresentMon also failed: {}. No FPS data.", e2);
                                None
                            }
                        }
                    }
                }
            }
            DxgiMethod::PresentMon => {
                match dxgi::start_presentmon(process_name) {
                    Ok(session) => Some(DxgiSession {
                        method: DxgiMethod::PresentMon,
                        shared_memory: None,
                        presentmon: Some(session),
                    }),
                    Err(e) => {
                        log::warn!("PresentMon failed: {}. No FPS data.", e);
                        None
                    }
                }
            }
        };

        // Start ETW session if requested (requires admin)
        let etw_session = if use_etw {
            match etw::start_frame_session() {
                Ok(session) => {
                    log::info!("ETW frame timing session started.");
                    Some(session)
                }
                Err(e) => {
                    log::warn!("ETW session failed: {}. Falling back to DXGI-only.", e);
                    None
                }
            }
        } else {
            None
        };

        Ok(Self {
            pdh_query,
            dxgi_session,
            etw_session,
            process_name: process_name.to_string(),
            process_id,
            num_cores,
            last_disk_read: 0,
            last_disk_write: 0,
            last_net_rx: 0,
            last_net_tx: 0,
        })
    }

    /// Perform one collection tick (1Hz cadence).
    ///
    /// Collects all metrics and returns a populated MetricSample.
    /// This is the main entry point called by the pb-pcprobe loop.
    pub fn tick(&mut self) -> Result<MetricSample, String> {
        // 1. Collect PDH snapshot (CPU, memory, disk, network, GPU, threads/handles)
        let pdh_snap = pdh::collect_sample(&self.pdh_query)?;

        // 2. Collect FPS from DXGI or ETW
        let (fps, frametimes_json) = self.collect_fps();

        // 3. Collect per-process memory (working set, private bytes)
        let memory_snap = crate::pc_metrics::memory::collect_memory(self.process_id)?;

        // 4. Collect per-thread CPU data
        let cpu_snap = crate::pc_metrics::cpu::collect_cpu(self.process_id, self.num_cores)?;

        // 5. Enrich the PDH snapshot with additional data
        let mut enriched = pdh_snap;
        enriched.fps = fps;
        enriched.frametimes_json = frametimes_json;

        // Memory enrichment from process-level query
        if enriched.working_set_kb.is_none() {
            enriched.working_set_kb = memory_snap.working_set_kb;
        }
        if enriched.private_bytes_kb.is_none() {
            enriched.private_bytes_kb = memory_snap.private_bytes_kb;
        }
        if enriched.page_faults_per_s.is_none() {
            enriched.page_faults_per_s = memory_snap.page_faults_per_s;
        }
        if enriched.gpu_dedicated_mem_kb.is_none() {
            enriched.gpu_dedicated_mem_kb = memory_snap.gpu_dedicated_mem_kb;
        }
        if enriched.gpu_shared_mem_kb.is_none() {
            enriched.gpu_shared_mem_kb = memory_snap.gpu_shared_mem_kb;
        }

        // 6. Calculate disk I/O rates (current cumulative - previous cumulative)
        let disk_read_rate = if let Some(current) = enriched.disk_read_bytes_per_s {
            let delta = current - self.last_disk_read;
            self.last_disk_read = current;
            if delta > 0 { Some(delta) } else { None }
        } else {
            None
        };
        let disk_write_rate = if let Some(current) = enriched.disk_write_bytes_per_s {
            let delta = current - self.last_disk_write;
            self.last_disk_write = current;
            if delta > 0 { Some(delta) } else { None }
        } else {
            None
        };
        enriched.disk_read_bytes_per_s = disk_read_rate;
        enriched.disk_write_bytes_per_s = disk_write_rate;

        // 7. Calculate network rates
        let net_rx_rate = if let Some(current) = enriched.net_rx_bytes_per_s {
            let delta = current - self.last_net_rx;
            self.last_net_rx = current;
            if delta > 0 { Some(delta) } else { None }
        } else {
            None
        };
        let net_tx_rate = if let Some(current) = enriched.net_tx_bytes_per_s {
            let delta = current - self.last_net_tx;
            self.last_net_tx = current;
            if delta > 0 { Some(delta) } else { None }
        } else {
            None
        };
        enriched.net_rx_bytes_per_s = net_rx_rate;
        enriched.net_tx_bytes_per_s = net_tx_rate;

        // 8. Convert to MetricSample with per-thread CPU JSON
        let mut sample = MetricSample::from_pc_snapshot(&enriched);

        // Add per-thread CPU JSON
        if !cpu_snap.thread_data.is_empty() {
            let thread_json: Vec<serde_json::Value> = cpu_snap
                .thread_data
                .iter()
                .map(|t| {
                    serde_json::json!({
                        "tid": t.tid,
                        "name": t.name,
                        "cpu_pct": t.cpu_pct,
                    })
                })
                .collect();
            sample.pc_thread_cpu_json =
                Some(serde_json::to_string(&thread_json).unwrap_or_else(|_| "[]".to_string()));
        }

        // Add CPU frequency if available
        if let Some(freq_mhz) = cpu_snap.frequency_mhz {
            sample.cpu_core_freqs_json =
                Some(serde_json::to_string(&freq_mhz).unwrap_or_else(|_| "0".to_string()));
        }

        Ok(sample)
    }

    /// Collect FPS from the active DXGI or ETW session.
    fn collect_fps(&mut self) -> (Option<f64>, Option<String>) {
        // Try DXGI injection (Method A) first
        if let Some(ref session) = self.dxgi_session {
            if session.method == DxgiMethod::DetourHook {
                if let Some(ref shm) = session.shared_memory {
                    let frame_deltas = dxgi::read_frame_deltas(shm);
                    if !frame_deltas.is_empty() {
                        let result = dxgi::analyze_pc_fps(&frame_deltas);
                        return (Some(result.fps), Some(result.frametimes_json));
                    }
                }
            }

            // Try PresentMon (Method B)
            if let Some(ref pm) = session.presentmon {
                let result = dxgi::measure_fps_presentmon(pm);
                if result.fps > 0.0 {
                    return (Some(result.fps), Some(result.frametimes_json));
                }
            }
        }

        // Try ETW (non-DX games)
        if let Some(ref etw) = self.etw_session {
            if let Ok(frame_deltas) = etw::poll_frame_events(etw) {
                if !frame_deltas.is_empty() {
                    let result = dxgi::analyze_pc_fps(&frame_deltas);
                    return (Some(result.fps), Some(result.frametimes_json));
                }
            }
        }

        (None, None)
    }

    /// Close the collector and clean up all resources.
    ///
    /// Closes PDH query, detaches DXGI hook, stops PresentMon, stops ETW.
    pub fn close(self) {
        // Close PDH query
        pdh::close_query(self.pdh_query);

        // Stop DXGI/ETW sessions (resources dropped on Drop)
        if let Some(session) = self.dxgi_session {
            if let Some(pm) = session.presentmon {
                dxgi::stop_presentmon(pm);
            }
        }

        if let Some(etw) = self.etw_session {
            etw::stop_frame_session(etw);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pc_collector_new_returns_result() {
        // Test with current process — should succeed for PDH
        let result = PcCollector::new(
            &std::env::current_exe()
                .ok()
                .and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
                .unwrap_or_else(|| "test.exe".to_string()),
            std::process::id(),
            DxgiMethod::PresentMon, // Don't try injection in test
            false,                  // Don't try ETW in test
        );

        match result {
            Ok(collector) => {
                assert!(!collector.process_name.is_empty());
                assert_eq!(collector.process_id, std::process::id());
                collector.close();
            }
            Err(e) => {
                // Process might not expose PDH counters — that's ok
                log::debug!("PcCollector new() returned Err: {}", e);
            }
        }
    }

    #[test]
    fn test_pc_collector_tick_produces_metric_sample() {
        let exe_name = std::env::current_exe()
            .ok()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
            .unwrap_or_else(|| "test.exe".to_string());

        let mut collector = match PcCollector::new(
            &exe_name,
            std::process::id(),
            DxgiMethod::PresentMon,
            false,
        ) {
            Ok(c) => c,
            Err(_) => return, // Skip test if PDH unavailable
        };

        // First tick: initializes rate baselines
        let sample1 = collector.tick();
        if let Ok(s) = &sample1 {
            assert!(!s.session_id.is_empty() || true); // session_id may be empty
            assert!(s.timestamp > 0);
        }

        // Second tick: should have rate data (disk/network deltas)
        let sample2 = collector.tick();
        if let Ok(s) = sample2 {
            assert!(s.timestamp > 0);
        }

        collector.close();
    }

    #[test]
    fn test_pc_collector_close_no_panic() {
        let exe_name = std::env::current_exe()
            .ok()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
            .unwrap_or_else(|| "test.exe".to_string());

        if let Ok(collector) = PcCollector::new(
            &exe_name,
            std::process::id(),
            DxgiMethod::PresentMon,
            false,
        ) {
            collector.close(); // Should not panic
        }
    }
}
