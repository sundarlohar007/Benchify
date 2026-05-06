// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BeginMarker.cs — Scoped marker helper using C# IDisposable pattern.
// Per D-02: Usage: using(new BeginMarker("boss_fight")) { ... }
// Auto-calls EndMarker on Dispose (scope exit).

#if PERFORMANCE_BENCH

using System;

namespace Benchify
{
    /// <summary>
    /// Scoped performance marker that auto-ends on Dispose.
    /// Call BeginMarker on construction, EndMarker on Dispose.
    ///
    /// Usage:
    /// <code>
    /// using (new BeginMarker("boss_fight"))
    /// {
    ///     // Profiled code block
    ///     SpawnBoss();
    /// }
    /// // EndMarker called automatically here
    /// </code>
    /// </summary>
    public class BeginMarker : IDisposable
    {
        private readonly string _name;
        private bool _disposed;

        /// <summary>
        /// Create a scoped marker with the given name.
        /// Immediately calls BenchifyPlugin.BeginMarker.
        /// </summary>
        public BeginMarker(string name)
        {
            _name = name ?? "unnamed_marker";
            _disposed = false;
            BenchifyPlugin.BeginMarker(_name);
        }

        /// <summary>
        /// End the marker scope. Called automatically by `using` statement.
        /// Safe to call multiple times (idempotent).
        /// </summary>
        public void Dispose()
        {
            if (!_disposed)
            {
                _disposed = true;
                BenchifyPlugin.EndMarker();
            }
        }
    }
}

#endif // PERFORMANCE_BENCH
