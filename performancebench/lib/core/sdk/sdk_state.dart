// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// SDK-level feature flags and state for the profiling engine.
///
/// These flags control which metric parsers are active during live profiling.
/// All flags are mutable — changed via settings or platform detection.
class SdkState {
  /// Whether Disk I/O parsing is enabled.
  /// Default on for Android in v1.5. Controlled via per-session config.
  bool diskIoSdkEnabled;

  /// Whether auto-detected issues engine is enabled.
  /// Default-off per D-03: user opts in for post-session issue scanning.
  bool detectedIssuesEnabled;

  SdkState({this.diskIoSdkEnabled = true, this.detectedIssuesEnabled = false});
}
