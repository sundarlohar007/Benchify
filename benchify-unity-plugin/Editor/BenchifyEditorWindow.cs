// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyEditorWindow.cs — Editor stats window for Unity.
// Per D-03: Read-only stats display during Play mode.
// Shows FPS, draw calls, batches, SetPass, Mono heap, GC alloc.
// Accessible via Window > Benchify Profiler menu.

#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using System.Diagnostics;

namespace Benchify.Editor
{
    /// <summary>
    /// Editor window displaying live profiling stats during Play mode.
    /// Auto-refreshes via EditorApplication.update callback.
    /// Read-only — profiling control is via the PerformanceBench desktop app.
    /// </summary>
    public class BenchifyEditorWindow : EditorWindow
    {
        private const float MinFpsForGreen = 55f;
        private const float MinFpsForYellow = 30f;
        private const float GcAllocWarnKb = 1024f; // 1 MB per frame

        private Vector2 _scrollPos;

        [MenuItem("Window/Benchify Profiler")]
        public static void ShowWindow()
        {
            var window = GetWindow<BenchifyEditorWindow>("Benchify Profiler");
            window.minSize = new Vector2(320, 280);
            window.Show();
        }

        private void OnEnable()
        {
            EditorApplication.update += Repaint;
        }

        private void OnDisable()
        {
            EditorApplication.update -= Repaint;
        }

        private void OnGUI()
        {
            if (!Application.isPlaying)
            {
                EditorGUILayout.HelpBox(
                    "Enter Play mode to view profiling stats.\n\n" +
                    "Benchify Profiler displays live draw calls, memory, and FPS\n" +
                    "during Play mode. Full profiling control is available in the\n" +
                    "PerformanceBench desktop app.",
                    MessageType.Info
                );

                if (GUILayout.Button("Open PerformanceBench Desktop", GUILayout.Height(30)))
                {
                    OpenDesktopApp();
                }
                return;
            }

            var plugin = BenchifyPlugin.Instance;
            if (plugin == null)
            {
                EditorGUILayout.HelpBox("BenchifyPlugin not initialized.", MessageType.Warning);
                return;
            }

            _scrollPos = EditorGUILayout.BeginScrollView(_scrollPos);

            // ── FPS ──────────────────────────────────────────
            DrawFpsSection(plugin);

            // ── Rendering Stats ──────────────────────────────
            DrawRenderingSection(plugin);

            // ── Memory ────────────────────────────────────────
            DrawMemorySection(plugin);

            EditorGUILayout.EndScrollView();

            EditorGUILayout.Space(10);
            if (GUILayout.Button("Open PerformanceBench Desktop", GUILayout.Height(25)))
            {
                OpenDesktopApp();
            }
        }

        private void DrawFpsSection(BenchifyPlugin plugin)
        {
            float fps = plugin.CurrentFps;
            Color fpsColor = fps >= MinFpsForGreen ? Color.green
                : fps >= MinFpsForYellow ? Color.yellow
                : Color.red;

            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            EditorGUILayout.LabelField("FPS", EditorStyles.boldLabel);

            var fpsStyle = new GUIStyle(EditorStyles.largeLabel)
            {
                normal = { textColor = fpsColor },
                fontStyle = FontStyle.Bold,
                fontSize = 24
            };
            EditorGUILayout.LabelField($"{fps:F1}", fpsStyle, GUILayout.Height(32));
            EditorGUILayout.EndVertical();
            EditorGUILayout.Space(4);
        }

        private void DrawRenderingSection(BenchifyPlugin plugin)
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            EditorGUILayout.LabelField("Rendering", EditorStyles.boldLabel);

            EditorGUILayout.LabelField("Draw Calls", plugin.DrawCalls.ToString("N0"));
            EditorGUILayout.LabelField("Batches", plugin.Batches.ToString("N0"));
            EditorGUILayout.LabelField("SetPass Calls", plugin.SetPassCalls.ToString("N0"));

            EditorGUILayout.EndVertical();
            EditorGUILayout.Space(4);
        }

        private void DrawMemorySection(BenchifyPlugin plugin)
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            EditorGUILayout.LabelField("Memory", EditorStyles.boldLabel);

            // Mono heap with progress bar
            long monoHeapMb = plugin.MonoHeapKb / 1024;
            float heapRatio = Mathf.Clamp01(monoHeapMb / 1024f); // 1 GB max scale
            EditorGUILayout.LabelField("Mono Heap", $"{monoHeapMb:N0} MB");
            EditorGUILayout.Slider(heapRatio, 0f, 1f, GUILayout.ExpandWidth(true));

            // GC alloc with warning color
            long gcKb = plugin.GcAllocKb;
            Color gcColor = gcKb > GcAllocWarnKb ? Color.red : GUI.contentColor;
            var gcStyle = new GUIStyle(EditorStyles.label)
            {
                normal = { textColor = gcColor }
            };
            EditorGUILayout.LabelField("GC Alloc/frame", $"{gcKb:N0} KB", gcStyle);

            EditorGUILayout.EndVertical();
        }

        /// <summary>
        /// Launch the PerformanceBench desktop application.
        /// Searches common install paths for the executable.
        /// </summary>
        private void OpenDesktopApp()
        {
#if UNITY_STANDALONE_WIN
            var psi = new ProcessStartInfo
            {
                FileName = "performancebench.exe",
                UseShellExecute = true
            };
            try { Process.Start(psi); } catch { /* Graceful failure */ }
#elif UNITY_STANDALONE_OSX
            var psi = new ProcessStartInfo
            {
                FileName = "/Applications/PerformanceBench.app/Contents/MacOS/performancebench",
                UseShellExecute = true
            };
            try { Process.Start(psi); } catch { /* Graceful failure */ }
#elif UNITY_STANDALONE_LINUX
            var psi = new ProcessStartInfo
            {
                FileName = "performancebench",
                UseShellExecute = true
            };
            try { Process.Start(psi); } catch { /* Graceful failure */ }
#endif
        }
    }
}

#endif // UNITY_EDITOR
