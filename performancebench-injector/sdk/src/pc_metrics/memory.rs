// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! PC memory metrics: working set, private bytes, GPU committed memory.
//!
//! Per D-11 and §19.2: PC-appropriate memory metrics, not forced mobile parity.
//! Uses GetProcessMemoryInfo (working set, private bytes) and PDH counters
//! for GPU committed memory.
//!
//! All code is `#[cfg(windows)]` gated.

/// Snapshot of PC memory metrics for a single process.
#[derive(Debug, Clone, Default)]
pub struct PcMemorySnapshot {
    pub working_set_kb: Option<i64>,
    pub private_bytes_kb: Option<i64>,
    pub gpu_dedicated_mem_kb: Option<i64>,
    pub gpu_shared_mem_kb: Option<i64>,
    pub page_faults_per_s: Option<f64>,
}

// ---------------------------------------------------------------------------
// Windows FFI bindings for memory collection
// ---------------------------------------------------------------------------

#[cfg(windows)]
mod ffi {
    use std::ffi::c_void;

    pub const PROCESS_QUERY_INFORMATION: u32 = 0x0400;
    pub const PROCESS_VM_READ: u32 = 0x0010;

    /// Windows PROCESS_MEMORY_COUNTERS_EX structure.
    #[repr(C)]
    pub struct ProcessMemoryCountersEx {
        pub cb: u32,
        pub page_fault_count: u32,
        pub peak_working_set_size: usize,
        pub working_set_size: usize,
        pub quota_peak_paged_pool_usage: usize,
        pub quota_paged_pool_usage: usize,
        pub quota_peak_non_paged_pool_usage: usize,
        pub quota_non_paged_pool_usage: usize,
        pub pagefile_usage: usize,
        pub peak_pagefile_usage: usize,
        pub private_usage: usize,
    }

    extern "system" {
        pub fn GetCurrentProcess() -> *mut c_void;

        pub fn OpenProcess(
            dw_desired_access: u32,
            b_inherit_handle: i32,
            dw_process_id: u32,
        ) -> *mut c_void;

        pub fn CloseHandle(h_object: *mut c_void) -> i32;

        pub fn K32GetProcessMemoryInfo(
            h_process: *mut c_void,
            ppsmem_counters: *mut ProcessMemoryCountersEx,
            cb: u32,
        ) -> i32;
    }
}

/// Collect memory metrics for a process by PID.
///
/// Uses K32GetProcessMemoryInfo for working set and private bytes.
/// Returns working_set_kb and private_bytes_kb from the PROCESS_MEMORY_COUNTERS_EX
/// structure. Also captures page_fault_count.
///
/// GPU committed memory comes from PDH snapshots (not from this function).
#[cfg(windows)]
pub fn collect_memory(process_id: u32) -> Result<PcMemorySnapshot, String> {
    // Open the target process
    let h_process = if process_id == std::process::id() {
        // Use pseudo-handle for current process (faster, no permissions needed)
        unsafe { ffi::GetCurrentProcess() }
    } else {
        let handle = unsafe {
            ffi::OpenProcess(
                ffi::PROCESS_QUERY_INFORMATION | ffi::PROCESS_VM_READ,
                0,
                process_id,
            )
        };
        if handle.is_null() {
            return Err(format!(
                "OpenProcess failed for PID {}: access denied",
                process_id
            ));
        }
        handle
    };

    let mut counters = ffi::ProcessMemoryCountersEx {
        cb: std::mem::size_of::<ffi::ProcessMemoryCountersEx>() as u32,
        page_fault_count: 0,
        peak_working_set_size: 0,
        working_set_size: 0,
        quota_peak_paged_pool_usage: 0,
        quota_paged_pool_usage: 0,
        quota_peak_non_paged_pool_usage: 0,
        quota_non_paged_pool_usage: 0,
        pagefile_usage: 0,
        peak_pagefile_usage: 0,
        private_usage: 0,
    };

    let result = unsafe {
        ffi::K32GetProcessMemoryInfo(
            h_process,
            &mut counters as *mut ffi::ProcessMemoryCountersEx,
            counters.cb,
        )
    };

    // Close handle if we opened one (but NOT the pseudo-handle)
    if process_id != std::process::id() && !h_process.is_null() {
        unsafe { ffi::CloseHandle(h_process); }
    }

    if result == 0 {
        return Err(format!(
            "K32GetProcessMemoryInfo failed for PID {}",
            process_id
        ));
    }

    Ok(PcMemorySnapshot {
        working_set_kb: Some((counters.working_set_size / 1024) as i64),
        private_bytes_kb: Some((counters.private_usage / 1024) as i64),
        page_faults_per_s: Some(counters.page_fault_count as f64),
        // GPU memory filled separately from PDH snapshot
        gpu_dedicated_mem_kb: None,
        gpu_shared_mem_kb: None,
    })
}

#[cfg(not(windows))]
pub fn collect_memory(_process_id: u32) -> Result<PcMemorySnapshot, String> {
    Err("PC memory collection is Windows-only".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pc_memory_snapshot_default() {
        let snap = PcMemorySnapshot::default();
        assert!(snap.working_set_kb.is_none());
        assert!(snap.private_bytes_kb.is_none());
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "Memory collection requires Windows")]
    fn test_collect_memory_returns_data_for_current_process() {
        // This test FAILS in RED because collect_memory is a stub returning Err.
        // In GREEN, it should return Ok with memory data for the current process.
        let result = collect_memory(std::process::id());
        assert!(
            result.is_ok(),
            "collect_memory should return Ok for current process, got: {:?}",
            result
        );

        let snap = result.unwrap();
        // Working set should be non-zero for a running process
        assert!(snap.working_set_kb.is_some(), "Working set should be present");
        assert!(
            snap.working_set_kb.unwrap() > 0,
            "Working set should be > 0 KB for a running process"
        );
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "Memory collection requires Windows")]
    fn test_collect_memory_returns_private_bytes() {
        let result = collect_memory(std::process::id());
        assert!(result.is_ok(), "collect_memory should return Ok");
        let snap = result.unwrap();
        assert!(snap.private_bytes_kb.is_some(), "Private bytes should be present");
        assert!(
            snap.private_bytes_kb.unwrap() > 0,
            "Private bytes should be > 0 KB"
        );
    }
}
