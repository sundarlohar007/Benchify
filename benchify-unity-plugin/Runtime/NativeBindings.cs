// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// NativeBindings.cs — P/Invoke bindings to Rust benchify_engine native library.
// Per D-01: C# wrapper loading Rust .so/.dll for marker + frame stat streaming.
// Threat mitigation (T-05-01): Loads from known Unity Plugin paths only — no PATH search.

using System;
using System.Runtime.InteropServices;

namespace Benchify
{
    /// <summary>
    /// P/Invoke bindings to the Rust benchify_engine native library.
    /// Per-platform .so/.dll/.dylib naming handled via DllImport.
    ///
    /// Platform library names:
    /// - Windows: benchify_engine.dll
    /// - macOS:   libbenchify_engine.dylib
    /// - Linux:   libbenchify_engine.so
    /// </summary>
    internal static class NativeBindings
    {
        /// <summary>
        /// Begin a named scoped marker in the Rust engine_core.
        /// </summary>
        [DllImport("benchify_engine", EntryPoint = "benchify_engine_begin_marker")]
        internal static extern void benchify_engine_begin_marker(
            [MarshalAs(UnmanagedType.LPStr)] string name
        );

        /// <summary>
        /// End the current scoped marker in the Rust engine_core.
        /// </summary>
        [DllImport("benchify_engine", EntryPoint = "benchify_engine_end_marker")]
        internal static extern void benchify_engine_end_marker();

        /// <summary>
        /// Push frame stats JSON to the Rust engine_core transport queue.
        /// JSON format matches engine_core::metrics::UnityFrameStats.to_json().
        /// </summary>
        [DllImport("benchify_engine", EntryPoint = "benchify_engine_queue_frame_stats")]
        internal static extern void benchify_engine_queue_frame_stats(
            [MarshalAs(UnmanagedType.LPStr)] string json
        );

        /// <summary>
        /// Native library load path resolution.
        /// Unity loads from Assets/Plugins/ by default.
        /// For UPM packages, the native lib can be bundled in ~/.benchify/ cache.
        /// </summary>
        static NativeBindings()
        {
            // Unity's native plugin importer handles .so/.dll/.dylib loading
            // from Assets/Plugins/[Platform]/ automatically.
            // No explicit LoadLibrary needed in standard Unity configuration.
        }
    }
}
