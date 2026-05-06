// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// AutoMarkerHook.cs — Static scene-load hook for automatic markers.
// Per D-01: Auto-marker triggers on scene transitions.
// Subscribes to SceneManager.sceneLoaded, creates markers with scene names.

#if PERFORMANCE_BENCH

using UnityEngine;
using UnityEngine.SceneManagement;

namespace Benchify
{
    /// <summary>
    /// Static auto-marker hook for scene lifecycle events.
    /// Automatically creates BeginMarker/EndMarker pairs on scene transitions.
    /// </summary>
    public static class AutoMarkerHook
    {
        private static bool _initialized;

        /// <summary>
        /// Initialize auto-marker hooks. Called once by BenchifyPlugin.Start.
        /// </summary>
        public static void Initialize()
        {
            if (_initialized) return;
            _initialized = true;

            SceneManager.sceneLoaded += OnSceneLoaded;
            SceneManager.sceneUnloaded += OnSceneUnloaded;
        }

        /// <summary>
        /// Teardown auto-marker hooks.
        /// </summary>
        public static void Shutdown()
        {
            if (!_initialized) return;
            _initialized = false;

            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
        }

        private static void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            OnSceneLoaded(scene.name, mode == LoadSceneMode.Additive);
        }

        /// <summary>
        /// Called when a scene is loaded (public for BenchifyPlugin to call).
        /// Creates an auto-marker with the scene name.
        /// </summary>
        public static void OnSceneLoaded(string sceneName, bool isAdditive)
        {
            string markerName = isAdditive
                ? $"Additive:{sceneName}"
                : $"Scene:{sceneName}";

            BenchifyPlugin.BeginMarker(markerName);

            // Scene load markers are instantaneous — end immediately.
            // The marker pair shows up in the timeline as a point event.
            BenchifyPlugin.EndMarker();
        }

        private static void OnSceneUnloaded(Scene scene)
        {
            string markerName = $"SceneUnload:{scene.name}";
            BenchifyPlugin.BeginMarker(markerName);
            BenchifyPlugin.EndMarker();
        }
    }
}

#endif // PERFORMANCE_BENCH
