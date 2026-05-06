/// JNI bridge: native function exports for Java dev.benchify.SdkLoader.
///
/// Naming convention matches Java package:
///   Java: dev.benchify.SdkLoader.nativeInit(Context, FpsOverlayView)
///   Rust: Java_dev_benchify_SdkLoader_nativeInit
///
/// Per D-10: Full ADB replacement — all metrics from native hooks and /proc reads.

use jni::JNIEnv;
use jni::objects::{JClass, JObject};
use jni::sys::{jint, jstring};

/// Called when the native library is loaded. Initializes android_logger.
#[no_mangle]
pub extern "system" fn JNI_OnLoad(
    _vm: jni::JavaVM,
    _reserved: *mut std::ffi::c_void,
) -> jint {
    #[cfg(target_os = "android")]
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Debug)
            .with_tag("PerformanceBenchSDK"),
    );
    jni::sys::JNI_VERSION_1_6
}

/// Initialize SDK: starts TCP server on port 8080 and metric collection at 1Hz.
/// Returns immediately (non-blocking).
#[no_mangle]
pub extern "system" fn Java_dev_benchify_SdkLoader_nativeInit(
    mut env: JNIEnv,
    _class: JClass,
    context: JObject,
    fps_overlay: JObject,
) {
    let _ctx = env.new_global_ref(context).ok();
    let _overlay = env.new_global_ref(fps_overlay).ok();

    log::info!("PerformanceBench SDK nativeInit called");

    std::thread::spawn(|| {
        crate::transport::start_server();
    });

    std::thread::spawn(|| {
        crate::transport::start_metric_collection();
    });
}

/// Begin streaming metrics. No-op if already started.
#[no_mangle]
pub extern "system" fn Java_dev_benchify_SdkLoader_nativeStart(
    _env: JNIEnv,
    _class: JClass,
) {
    log::info!("SDK nativeStart");
    crate::transport::resume_streaming();
}

/// Stop metric collection and TCP server.
#[no_mangle]
pub extern "system" fn Java_dev_benchify_SdkLoader_nativeStop(
    _env: JNIEnv,
    _class: JClass,
) {
    log::info!("SDK nativeStop");
    crate::transport::stop_streaming();
}

/// Report JS heap memory from WebView JS bridge.
///
/// Called by Java WebViewBridge.nativeReportJsHeap(int).
/// Per T-04-17: Lock-free AtomicI32 — no allocations or blocking in JNI path.
#[no_mangle]
pub extern "system" fn Java_dev_benchify_WebViewBridge_nativeReportJsHeap(
    _env: JNIEnv,
    _class: JClass,
    used_heap_kb: jint,
) {
    crate::metrics::webview_js::report_js_heap(used_heap_kb);
}

/// Return current metrics snapshot as JSON string.
#[no_mangle]
pub extern "system" fn Java_dev_benchify_SdkLoader_nativeGetStats(
    env: JNIEnv,
    _class: JClass,
) -> jstring {
    let snapshot = crate::transport::get_current_stats();
    let json = serde_json::to_string(&snapshot).unwrap_or_else(|_| "{}".into());
    match env.new_string(&json) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Handle automation broadcast command from BenchifyBroadcastReceiver.
/// Called from Java: `nativeHandleCommand(String action, String payloadJson)`.
/// Returns JSON response string via JNI.
#[no_mangle]
pub extern "system" fn Java_dev_benchify_BenchifyBroadcastReceiver_nativeHandleCommand(
    mut env: JNIEnv,
    _class: JClass,
    action: JString,
    payload_json: JString,
) -> jstring {
    let action: String = env.get_string(&action).unwrap_or_default().into();
    let payload: String = env.get_string(&payload_json).unwrap_or_default().into();
    let response = crate::automation::handle_command(&action, &payload);
    match env.new_string(&response) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}
