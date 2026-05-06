/// Transport layer: TCP server on 127.0.0.1:8080 emitting newline-delimited JSON.
///
/// Per D-11: JSON over TCP port 8080. Matches iOS collector.py pattern.
/// Per D-13: Always-on from app start. Desktop connects anytime.
///
/// Threat mitigations (T-04-08, T-04-12):
/// - Bound to 127.0.0.1 only — not routable.
/// - Dedicated thread with 1s sleep. If collection takes >1s, skip cycle.

use std::io::Write;
use std::net::{TcpListener, TcpStream};
use std::sync::{Mutex, atomic::{AtomicBool, Ordering}};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::models::MetricSample;
use crate::metrics::{fps, cpu, memory, network, gpu, webview_js, net_per_process};

static STREAMING_ACTIVE: AtomicBool = AtomicBool::new(false);
static SERVER_RUNNING: AtomicBool = AtomicBool::new(false);

lazy_static::lazy_static! {
    static ref SAMPLE_QUEUE: Mutex<Vec<MetricSample>> = Mutex::new(Vec::new());
    static ref LATEST_SAMPLE: Mutex<Option<MetricSample>> = Mutex::new(None);
    /// Event queue for markers and other JSON events pushed via automation.
    static ref EVENT_QUEUE: Mutex<Vec<String>> = Mutex::new(Vec::new());
}

struct MetricState {
    last_cpu_utime: u64,
    last_cpu_stime: u64,
    last_cpu_total: u64,
    last_net: Vec<network::NetInterface>,
    frame_deltas: Vec<u64>,
    session_id: String,
}

static METRIC_STATE: once_cell::sync::Lazy<Mutex<MetricState>> = once_cell::sync::Lazy::new(|| {
    Mutex::new(MetricState {
        last_cpu_utime: 0,
        last_cpu_stime: 0,
        last_cpu_total: 0,
        last_net: Vec::new(),
        frame_deltas: Vec::new(),
        session_id: String::new(),
    })
});

pub fn set_session_id(id: &str) {
    METRIC_STATE.lock().ok().map(|mut s| s.session_id = id.to_string());
}

/// Start TCP server on 127.0.0.1:8080. Accepts one client at a time.
pub fn start_server() {
    if SERVER_RUNNING.swap(true, Ordering::SeqCst) { return; }

    let listener = match TcpListener::bind("127.0.0.1:8080") {
        Ok(l) => l,
        Err(e) => {
            log::error!("TCP bind failed: {}", e);
            SERVER_RUNNING.store(false, Ordering::SeqCst);
            return;
        }
    };

    listener.set_nonblocking(true).ok();
    log::info!("SDK TCP server on 127.0.0.1:8080");

    while SERVER_RUNNING.load(Ordering::SeqCst) {
        match listener.accept() {
            Ok((mut stream, addr)) => {
                log::info!("Client connected: {}", addr);
                handle_client(&mut stream);
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(100));
            }
            Err(e) => {
                log::error!("Accept error: {}", e);
                std::thread::sleep(Duration::from_millis(500));
            }
        }
    }
}

fn handle_client(stream: &mut TcpStream) {
    stream.set_nonblocking(true).ok();

    // Drain queue
    if let Ok(mut queue) = SAMPLE_QUEUE.lock() {
        for sample in queue.drain(..) {
            send_sample(stream, &sample);
        }
    }

    while SERVER_RUNNING.load(Ordering::SeqCst) && STREAMING_ACTIVE.load(Ordering::SeqCst) {
        let sample = LATEST_SAMPLE.lock().ok().and_then(|s| s.clone());
        if let Some(s) = sample {
            if !send_sample(stream, &s) { return; }
        }
        std::thread::sleep(Duration::from_millis(100));
    }
}

fn send_sample(stream: &mut TcpStream, sample: &MetricSample) -> bool {
    match serde_json::to_string(sample) {
        Ok(json) => {
            match stream.write_all(format!("{}\n", json).as_bytes()) {
                Ok(_) => true,
                Err(e) => { log::error!("Write error: {}", e); false }
            }
        }
        Err(e) => { log::error!("Serialize error: {}", e); true }
    }
}

/// Start metric collection at 1Hz on a dedicated thread.
pub fn start_metric_collection() {
    STREAMING_ACTIVE.store(true, Ordering::SeqCst);
    log::info!("Metric collection started");

    while STREAMING_ACTIVE.load(Ordering::SeqCst) {
        let sample = collect_metrics();

        if let Ok(mut latest) = LATEST_SAMPLE.lock() { *latest = Some(sample.clone()); }
        if let Ok(mut queue) = SAMPLE_QUEUE.lock() {
            if queue.len() >= 60 { queue.remove(0); }
            queue.push(sample);
        }

        std::thread::sleep(Duration::from_secs(1));
    }
}

/// Collect one MetricSample with all available metrics.
fn collect_metrics() -> MetricSample {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_millis() as i64;
    let session_id = METRIC_STATE.lock().map(|s| s.session_id.clone()).unwrap_or_default();

    let mut sample = MetricSample { session_id, timestamp: now, ..Default::default() };

    if let Ok(mut state) = METRIC_STATE.lock() {
        // FPS from Choreographer frame deltas
        if !state.frame_deltas.is_empty() {
            sample.fps = Some(fps::compute_fps(&state.frame_deltas));
            let n = state.frame_deltas.len();
            if n > 60 {
                state.frame_deltas.drain(0..n - 60);
            }
        }

        // CPU from /proc/self/stat
        if let Ok(stat) = std::fs::read_to_string("/proc/self/stat") {
            let (utime, stime) = cpu::parse_proc_self_stat(&stat);
            let ud = utime.saturating_sub(state.last_cpu_utime);
            let sd = stime.saturating_sub(state.last_cpu_stime);
            #[cfg(not(target_os = "windows"))]
            {
                let ticks = unsafe { libc::sysconf(libc::_SC_CLK_TCK) } as f64;
                if ticks > 0.0 {
                    sample.cpu_app_pct = cpu::compute_app_cpu_pct((ud + sd) as f64 / ticks);
                }
            }
            state.last_cpu_utime = utime;
            state.last_cpu_stime = stime;

            if let Ok(ps) = std::fs::read_to_string("/proc/stat") {
                let total = cpu::parse_proc_stat_total(&ps);
                if total > 0 && state.last_cpu_total > 0 {
                    sample.cpu_system_pct = cpu::compute_system_cpu_pct(total.saturating_sub(state.last_cpu_total));
                }
                state.last_cpu_total = total;
            }
        }

        // Memory fallback from /proc/self/status
        if let Ok(status) = std::fs::read_to_string("/proc/self/status") {
            if let Some(rss) = memory::parse_vmrss(&status) {
                sample.memory_pss_kb = Some(rss as i32);
            }
        }

        // WebView JS memory from JNI bridge (per D-15)
        // Populated by Java WebViewBridge via addJavascriptInterface
        sample.memory_webview_kb = webview_js::get_webview_memory();

        // Per-process network from /proc/self/net/dev (per D-16)
        // net_per_process module tracks deltas independently
        {
            let net_result = net_per_process::collect(None);
            if net_result.total_tx > 0 || net_result.total_rx > 0 {
                sample.net_tx_bytes = Some(net_result.total_tx as i32);
                sample.net_rx_bytes = Some(net_result.total_rx as i32);
                sample.net_wifi_tx_bytes = Some(net_result.wifi_tx as i32);
                sample.net_wifi_rx_bytes = Some(net_result.wifi_rx as i32);
                sample.net_cellular_tx_bytes = Some(net_result.cellular_tx as i32);
                sample.net_cellular_rx_bytes = Some(net_result.cellular_rx as i32);
                sample.net_other_tx_bytes = Some(net_result.other_tx as i32);
                sample.net_other_rx_bytes = Some(net_result.other_rx as i32);
            }
        }

        // Network from /proc/self/net/dev (existing module — device-wide)
        if let Ok(dev) = std::fs::read_to_string("/proc/self/net/dev") {
            let curr = network::parse_net_dev(&dev);
            if !state.last_net.is_empty() {
                let deltas = network::compute_network_deltas(&state.last_net, &curr);
                let s = network::summarize_network_deltas(&deltas);
                sample.net_tx_bytes = Some(s.total_tx as i32);
                sample.net_rx_bytes = Some(s.total_rx as i32);
                sample.net_wifi_tx_bytes = Some(s.wifi_tx as i32);
                sample.net_wifi_rx_bytes = Some(s.wifi_rx as i32);
                sample.net_cellular_tx_bytes = Some(s.cellular_tx as i32);
                sample.net_cellular_rx_bytes = Some(s.cellular_rx as i32);
                sample.net_other_tx_bytes = Some(s.other_tx as i32);
                sample.net_other_rx_bytes = Some(s.other_rx as i32);
            }
            state.last_net = curr;
        }

        // GPU from sysfs (Android-only at runtime)
        #[cfg(target_os = "android")]
        {
            if let Ok(busy) = std::fs::read_to_string("/sys/class/kgsl/kgsl-3d0/gpubusy") {
                sample.gpu_pct = gpu::parse_adreno_gpubusy(&busy);
            }
            if sample.gpu_pct.is_none() {
                if let Ok(util) = std::fs::read_to_string("/sys/class/misc/mali0/device/utilization") {
                    sample.gpu_pct = gpu::parse_mali_utilization(&util);
                }
            }
            if let Ok(freq) = std::fs::read_to_string("/sys/class/kgsl/kgsl-3d0/gpuclk") {
                sample.gpu_freq_mhz = freq.trim().parse::<f64>().ok().map(|f| f / 1_000_000.0);
            }
        }
    }

    sample
}

pub fn push_frame_delta(delta_ns: u64) {
    METRIC_STATE.lock().ok().map(|mut s| s.frame_deltas.push(delta_ns));
}

pub fn resume_streaming() { STREAMING_ACTIVE.store(true, Ordering::SeqCst); }

pub fn stop_streaming() {
    STREAMING_ACTIVE.store(false, Ordering::SeqCst);
    SERVER_RUNNING.store(false, Ordering::SeqCst);
}

pub fn get_current_stats() -> MetricSample {
    LATEST_SAMPLE.lock().ok().and_then(|s| s.clone()).unwrap_or_default()
}

/// Pause metric collection without stopping the TCP server.
/// Used by automation PAUSE command.
pub fn pause_streaming() {
    STREAMING_ACTIVE.store(false, Ordering::SeqCst);
}

/// Push a JSON string event into the event queue (markers, etc.).
/// Used by automation MARKER command.
pub fn push_event_json(json_str: &str) {
    if let Ok(mut queue) = EVENT_QUEUE.lock() {
        queue.push(json_str.to_string());
    }
}

/// Get all buffered MetricSamples and events for EXPORT.
/// Returns serialized MetricSample vec plus marker events.
pub fn get_buffered_samples() -> Vec<MetricSample> {
    SAMPLE_QUEUE.lock()
        .map(|q| q.clone())
        .unwrap_or_default()
}
