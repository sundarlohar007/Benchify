package dev.benchify;

import android.content.Context;

/**
 * Native SDK loader — the single entry point from Smali-injected Application.onCreate().
 *
 * Loads libperformancebench_sdk.so and declares JNI native methods
 * matching Rust exports in jni_bridge.rs.
 *
 * The Smali patcher from Plan 04-01 references:
 *   Ldev/benchify/SdkLoader;->init(Landroid/content/Context;)V
 */
public class SdkLoader {

    static {
        System.loadLibrary("performancebench_sdk");
    }

    // --- JNI native method declarations ---

    /** Initialize SDK with app context and FPS overlay view reference. */
    public static native void nativeInit(Context context, FpsOverlayView overlay);

    /** Begin streaming metrics (no-op if already started). */
    public static native void nativeStart();

    /** Stop metric collection and close TCP connections. */
    public static native void nativeStop();

    /** Return current metrics snapshot as a JSON string. */
    public static native String nativeGetStats();

    // --- Public API ---

    /**
     * Initialize the PerformanceBench SDK.
     * Called from Smali-patched Application.onCreate() with the application context.
     *
     * This method:
     * 1. Creates the FPS overlay view
     * 2. Starts the BenchifyService foreground service
     * 3. Calls nativeInit to start TCP server and metric collection
     */
    public static void init(Context context) {
        // Create the FPS overlay view (attached to window by BenchifyService)
        // The overlay reference is passed to native code for FPS updates
        FpsOverlayView overlay = new FpsOverlayView(context);

        // Start foreground service which manages the overlay window
        BenchifyService.start(context, overlay);

        // Initialize native SDK — starts TCP server and metric collection
        nativeInit(context, overlay);
    }
}
