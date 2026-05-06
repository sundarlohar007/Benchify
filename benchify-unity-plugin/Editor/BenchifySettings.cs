// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifySettings.cs — Settings Provider for Benchify Unity Plugin.
// Accessible via Edit > Project Settings > Benchify.
// Configures TCP port, auto-marker toggle, stats refresh interval.

#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;

namespace Benchify.Editor
{
    /// <summary>
    /// ScriptableObject-based settings provider for Benchify plugin configuration.
    /// Registered via SettingsProvider attribute.
    /// </summary>
    internal class BenchifySettings : ScriptableObject
    {
        private const string SettingsPath = "Project/Benchify";

        [SerializeField]
        private int _tcpPort = 8080;

        [SerializeField]
        private bool _autoMarkersEnabled = true;

        [SerializeField]
        private float _statsRefreshInterval = 1.0f;

        public int TcpPort => _tcpPort;
        public bool AutoMarkersEnabled => _autoMarkersEnabled;
        public float StatsRefreshInterval => _statsRefreshInterval;

        private static BenchifySettings _instance;

        internal static BenchifySettings Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = CreateInstance<BenchifySettings>();
                }
                return _instance;
            }
        }

        [SettingsProvider]
        public static SettingsProvider CreateSettingsProvider()
        {
            var provider = new SettingsProvider(SettingsPath, SettingsScope.Project)
            {
                label = "Benchify",
                guiHandler = (searchContext) =>
                {
                    var settings = Instance;

                    EditorGUILayout.Space(10);
                    EditorGUILayout.LabelField("Benchify Profiler Settings", EditorStyles.boldLabel);

                    EditorGUILayout.Space(5);

                    // TCP Port
                    settings._tcpPort = EditorGUILayout.IntField(
                        new GUIContent("TCP Port",
                            "Port for TCP JSON streaming to PerformanceBench desktop app (default: 8080)"),
                        settings._tcpPort
                    );

                    EditorGUILayout.Space(5);

                    // Auto-marker toggle
                    settings._autoMarkersEnabled = EditorGUILayout.Toggle(
                        new GUIContent("Auto-Markers",
                            "Automatically create markers on scene load/unload"),
                        settings._autoMarkersEnabled
                    );

                    EditorGUILayout.Space(5);

                    // Stats refresh interval
                    settings._statsRefreshInterval = EditorGUILayout.Slider(
                        new GUIContent("Refresh Interval (s)",
                            "Stats aggregation interval in seconds"),
                        settings._statsRefreshInterval,
                        0.1f,
                        5.0f
                    );

                    EditorGUILayout.Space(20);

                    if (GUI.changed)
                    {
                        EditorUtility.SetDirty(settings);
                    }
                },
                keywords = new[] { "benchify", "profiler", "performance", "fps", "memory", "draw calls" }
            };

            return provider;
        }
    }
}

#endif // UNITY_EDITOR
