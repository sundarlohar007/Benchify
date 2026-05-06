// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

package dev.benchify;

import android.webkit.JavascriptInterface;
import android.webkit.WebView;

/**
 * WebView JavaScript bridge for memory collection.
 *
 * Per D-15: WebView JS collection via WebView.addJavascriptInterface().
 * Periodically calls window.performance.memory, reports usedJSHeapSize.
 *
 * Usage:
 *   WebViewBridge bridge = new WebViewBridge();
 *   bridge.install(webView);
 *   // Call periodically (e.g., every 5 seconds via Handler):
 *   bridge.probeJsMemory(webView);
 *
 * Thread safety:
 *   - install() and probeJsMemory() must be called on the UI thread.
 *   - JNI callback (nativeReportJsHeap) is lock-free (AtomicI32 in Rust).
 *
 * Threat T-04-14: Only exposes reportMemory(int) — single method, validated input.
 * No file access, no shell commands exposed to JS.
 */
public class WebViewBridge {

    /** JavaScript interface name exposed to web content. */
    private static final String JS_INTERFACE_NAME = "__benchify";

    /** Whether the bridge has been installed on the current WebView. */
    private boolean installed = false;

    /**
     * JNI native method — reports JS heap size to the Rust SDK.
     * Implemented in Rust: Java_dev_benchify_WebViewBridge_nativeReportJsHeap
     *
     * @param usedHeapKb usedJSHeapSize in kilobytes
     */
    public static native void nativeReportJsHeap(int usedHeapKb);

    /**
     * JavaScript snippet to probe window.performance.memory.usedJSHeapSize.
     *
     * Converts bytes to KB and reports via __benchify.reportMemory().
     * Safe to call on WebViews that don't support performance.memory (no-op).
     */
    private static final String JS_PROBE =
        "(function(){" +
        "  if(window.performance && window.performance.memory) {" +
        "    var used = window.performance.memory.usedJSHeapSize;" +
        "    if (typeof used === 'number' && used >= 0) {" +
        "      window.__benchify.reportMemory(Math.floor(used / 1024));" +
        "    }" +
        "  }" +
        "})()";

    /**
     * Install the JS bridge into the given WebView.
     *
     * Enables JavaScript and registers the __benchify object.
     * Safe to call multiple times — only installs once per instance.
     *
     * Must be called on the UI thread.
     *
     * @param webView The WebView to instrument (non-null)
     */
    public void install(WebView webView) {
        if (webView == null) {
            return;
        }
        if (installed) {
            return;
        }

        webView.getSettings().setJavaScriptEnabled(true);
        webView.addJavascriptInterface(new JsBridge(), JS_INTERFACE_NAME);
        installed = true;
    }

    /**
     * Probe the WebView for JavaScript memory usage.
     *
     * Executes JS_PROBE via evaluateJavascript on the UI thread.
     * The JS probe reads window.performance.memory.usedJSHeapSize
     * and calls window.__benchify.reportMemory(usedHeapKB).
     *
     * Must be called on the UI thread (or from a thread with a Handler
     * posting to the UI thread).
     *
     * @param webView The WebView to probe (non-null)
     */
    public void probeJsMemory(WebView webView) {
        if (webView == null) {
            return;
        }
        webView.post(() -> {
            webView.evaluateJavascript(JS_PROBE, null);
        });
    }

    /**
     * Reset installation state. Allows re-installing on a new WebView.
     */
    public void reset() {
        installed = false;
    }

    // ================================================================
    // JavaScript Interface — exposed to web content as window.__benchify
    // ================================================================

    /**
     * JavaScript interface class exposed to WebView content.
     *
     * Methods annotated with @JavascriptInterface are callable from JS:
     *   window.__benchify.reportMemory(usedHeapKB);
     */
    public static class JsBridge {

        /**
         * Report JS heap memory usage.
         *
         * Called from JavaScript via:
         *   window.__benchify.reportMemory(usedHeapKB);
         *
         * Forwards to native implementation via JNI.
         * Input is validated (non-negative, capped at 1GB) in Rust.
         *
         * @param usedHeapKb usedJSHeapSize in kilobytes (non-negative)
         */
        @JavascriptInterface
        public void reportMemory(int usedHeapKb) {
            nativeReportJsHeap(usedHeapKb);
        }
    }
}
