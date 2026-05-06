// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyPlugin.cs — Main MonoBehaviour for in-editor profiling.
// Per D-01: Connects to shared Rust engine_core library via P/Invoke.
// Per D-02: Provides BeginMarker/EndMarker API matching Phase 1 manual marker pattern.
// Per D-03: Read-only stats display — profiling control still via desktop app.

#if PERFORMANCE_BENCH

using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Profiling;
using System;

namespace Benchify
{
    /// <summary>
    /// Main Benchify profiling plugin MonoBehaviour.
    /// Singleton instantiated on load via RuntimeInitializeOnLoadMethod.
    /// Collects per-frame rendering + memory stats and streams to desktop app
    /// via Rust engine_core native library (P/Invoke).
    /// </summary>
    [DefaultExecutionOrder(-100)] // Run early to capture full frame
    public class BenchifyPlugin : MonoBehaviour
    {
        private static BenchifyPlugin _instance;

        // Frame stat tracking
        private float _frameAccumTime;
        private int _frameCount;
        private int _lastDrawCalls;
        private int _lastBatches;
        private int _lastSetPassCalls;
        private long _lastMonoHeapSize;
        private long _lastGcAlloc;
        private long _prevTotalAlloc;
        private int _lastTriangles;
        private int _lastVertices;

        // Rolling FPS
        private float _currentFps;

        /// <summary>
        /// Singleton instance accessor.
        /// </summary>
        public static BenchifyPlugin Instance => _instance;

        /// <summary>
        /// Auto-initialized on domain reload. Creates persistent GameObject
        /// that survives scene changes.
        /// </summary>
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Initialize()
        {
            if (_instance != null) return;

            var go = new GameObject("[Benchify Profiler]");
            DontDestroyOnLoad(go);
            _instance = go.AddComponent<BenchifyPlugin>();
        }

        private void Start()
        {
            // Bind scene load auto-markers (per D-01)
            SceneManager.sceneLoaded += OnSceneLoaded;

            // Initialize previous GC alloc baseline
            _prevTotalAlloc = (long)Profiler.GetTotalAllocatedMemoryLong();
        }

        private void OnDestroy()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
        }

        /// <summary>
        /// Auto-marker hook: fires when any scene is loaded.
        /// Handles additive scene loading by marking as "Additive:SceneName".
        /// </summary>
        private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            string markerName = mode == LoadSceneMode.Additive
                ? $"Additive:{scene.name}"
                : $"Scene:{scene.name}";

            BeginMarker(markerName);
            AutoMarkerHook.OnSceneLoaded(scene.name, mode == LoadSceneMode.Additive);
        }

        private void Update()
        {
            _frameCount++;
            _frameAccumTime += Time.unscaledDeltaTime;

            // Sample Unity stats each frame
            _lastDrawCalls = UnityStats.drawCalls;
            _lastBatches = UnityStats.batches;
            _lastSetPassCalls = UnityStats.setPassCalls;
            _lastMonoHeapSize = (long)Profiler.GetMonoHeapSizeLong();

            long currentTotalAlloc = (long)Profiler.GetTotalAllocatedMemoryLong();
            _lastGcAlloc = currentTotalAlloc - _prevTotalAlloc;
            if (_lastGcAlloc < 0) _lastGcAlloc = 0; // MonoSpan resets on domain reload
            _prevTotalAlloc = currentTotalAlloc;

            _lastTriangles = UnityStats.triangles;
            _lastVertices = UnityStats.vertices;

            // Aggregate at 1Hz and push to native engine_core
            if (_frameAccumTime >= 1.0f)
            {
                _currentFps = _frameCount / _frameAccumTime;

                // Build frame stats JSON and push to native library
                string json = BuildFrameStatsJson();
                NativeBindings.benchify_engine_queue_frame_stats(json);

                // Reset accumulators
                _frameAccumTime = 0f;
                _frameCount = 0;
            }
        }

        /// <summary>
        /// Build JSON payload matching engine_core::metrics::UnityFrameStats format.
        /// </summary>
        private string BuildFrameStatsJson()
        {
            return $"{{\"engine\":\"unity\",\"fps\":{_currentFps:F1},\"draw_calls\":{_lastDrawCalls},\"batches\":{_lastBatches},\"setpass_calls\":{_lastSetPassCalls},\"mono_heap_kb\":{_lastMonoHeapSize / 1024},\"gc_alloc_kb\":{_lastGcAlloc / 1024},\"triangles\":{_lastTriangles},\"vertices\":{_lastVertices}}}";
        }

        /// <summary>
        /// Public API: Begin a named scoped marker.
        /// Calls Rust engine_core::marker::begin_marker via P/Invoke.
        /// </summary>
        public static void BeginMarker(string name)
        {
            if (string.IsNullOrEmpty(name)) return;
            NativeBindings.benchify_engine_begin_marker(name);
        }

        /// <summary>
        /// Public API: End the current scoped marker.
        /// Calls Rust engine_core::marker::end_marker via P/Invoke.
        /// </summary>
        public static void EndMarker()
        {
            NativeBindings.benchify_engine_end_marker();
        }

        /// <summary>
        /// Current rolling FPS (1-second window).
        /// </summary>
        public float CurrentFps => _currentFps;

        /// <summary>
        /// Latest frame draw calls count.
        /// </summary>
        public int DrawCalls => _lastDrawCalls;

        /// <summary>
        /// Latest frame batches count.
        /// </summary>
        public int Batches => _lastBatches;

        /// <summary>
        /// Latest frame SetPass calls count.
        /// </summary>
        public int SetPassCalls => _lastSetPassCalls;

        /// <summary>
        /// Mono managed heap size in kilobytes.
        /// </summary>
        public long MonoHeapKb => _lastMonoHeapSize / 1024;

        /// <summary>
        /// GC allocation delta for the last frame in kilobytes.
        /// </summary>
        public long GcAllocKb => _lastGcAlloc / 1024;
    }
}

#endif // PERFORMANCE_BENCH
