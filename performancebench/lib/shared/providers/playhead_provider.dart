// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared playhead timestamp in milliseconds — synced between video player
/// and chart replay. Updated by both video scrub and chart drag/tap.
///
/// When the video position changes, charts re-render with a cursor at
/// this timestamp. When a chart is tapped or dragged, the video seeks
/// to this timestamp.
///
/// Pattern (per D-06, 32.9):
/// - Video scrubbed  → playheadProvider updated → charts re-render
/// - Chart tapped    → playheadProvider updated → video.seek()
/// - Scrub bar drag  → playheadProvider updated → both update
final playheadProvider = StateProvider<int?>((ref) => null);

/// Origin of the most recent playhead update.
///
/// Used to break the feedback loop between video and charts: each consumer
/// checks the source before applying its own seek/scroll, so a video-driven
/// update doesn't cause the video to seek itself.
enum PlayheadSource {
  /// No playhead activity yet (initial state).
  none,

  /// Video position changed → charts should update; video should NOT seek.
  video,

  /// Chart tapped/dragged → video should seek; charts should NOT update position.
  chart,

  /// Shared scrub bar dragged → both video and charts should update.
  scrubBar,
}

/// Last source that moved the playhead.
///
/// Replaced the prior `StateProvider<String>` (B-005): a typo in any of the
/// caller sites silently bypassed the loop guard and produced runaway
/// scrub/seek loops. The enum makes typos a compile error.
final playheadSourceProvider =
    StateProvider<PlayheadSource>((ref) => PlayheadSource.none);
