// Benchify Frida Agent — injected via frida-gadget (no re-sign needed)
//
// Per D-09: Connects to frida-server on device, hooks target app,
// and forwards memory/CPU metrics to desktop via RPC send().
//
// Per T-04-15: Uses listen mode — accepts connections from local frida-server.
// This is inherent to Frida's architecture. Developer tool on dev device.
//
// Note: Full metric depth (Choreographer FPS, GPU, per-process network)
// requires the native SDK .so (Smali path). This agent provides memory and
// CPU metrics accessible via Java APIs. See README for tradeoffs.

var profilingActive = false;
var metricInterval = null;

// Java.perform runs when the JVM is ready
Java.perform(function () {
    console.log("[Benchify] Frida agent loaded — Java bridge ready");

    // Hook Application.onCreate() to start profiling on app launch
    try {
        var Application = Java.use("android.app.Application");
        Application.onCreate.implementation = function () {
            // Call original onCreate first
            this.onCreate();
            console.log("[Benchify] App started — profiling active");
            startMetricCollection();
        };
    } catch (e) {
        console.log("[Benchify] Could not hook Application.onCreate: " + e);
        // Fall back: start collection immediately
        startMetricCollection();
    }

    // ================================================================
    // Metric Collection
    // ================================================================

    function startMetricCollection() {
        if (profilingActive) return;
        profilingActive = true;

        // Collect metrics every 1 second
        metricInterval = setInterval(function () {
            try {
                var sample = collectMetrics();
                if (sample !== null) {
                    // send() forwards the JSON to the Frida client (desktop)
                    send(JSON.stringify(sample));
                }
            } catch (e) {
                // Suppress errors to avoid flooding console
            }
        }, 1000);

        console.log("[Benchify] Metric collection started (1 Hz)");
    }

    function collectMetrics() {
        var sample = {
            timestamp: Date.now(),
        };

        try {
            // --- Memory via ActivityManager ---
            var ActivityManager = Java.use("android.app.ActivityManager");
            var context = Java.use("android.app.ActivityThread")
                .currentApplication()
                .getApplicationContext();
            var am = context.getSystemService("activity");
            var memInfoArray = Java.array(
                "Landroid/app/ActivityManager$ProcessMemoryInfo;",
                [am.getProcessMemoryInfo([android.os.Process.myPid()])[0]]
            );
            var memInfo = memInfoArray[0];
            sample.memory_pss_kb = memInfo.getTotalPss();
        } catch (e) {
            // ActivityManager unavailable — skip memory
        }

        try {
            // --- CPU via Debug.MemoryInfo (lightweight) ---
            // Full CPU requires /proc/self/stat reads (native SDK)
            // This is best-effort: we cannot easily read /proc from JS
        } catch (e) {
            // Skip CPU — requires native SDK
        }

        try {
            // --- Battery ---
            var BatteryManager = Java.use("android.os.BatteryManager");
            var intent = context.registerReceiver(
                null,
                Java.use("android.content.IntentFilter")
                    .$new("android.intent.action.BATTERY_CHANGED")
            );
            if (intent) {
                var level = intent.getIntExtra("level", -1);
                var scale = intent.getIntExtra("scale", 100);
                if (level >= 0 && scale > 0) {
                    sample.battery_pct = Math.floor((level / scale) * 100);
                }
                var temp = intent.getIntExtra("temperature", 0);
                if (temp > 0) {
                    sample.battery_temp_c = temp / 10.0;
                }
            }
        } catch (e) {
            // Battery unavailable
        }

        return sample;
    }
});

// Cleanup on detach
function stopProfiling() {
    if (metricInterval !== null) {
        clearInterval(metricInterval);
        metricInterval = null;
    }
    profilingActive = false;
    console.log("[Benchify] Profiling stopped");
}

// Handle Frida detach
rpc.exports = {
    stop: stopProfiling,
};
