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

/// Whether the playhead was last moved by the video, chart, or scrub bar.
///
/// Prevents feedback loops where video seeks chart which seeks video.
/// Consumers:
/// - 'video': video position changed → charts should update; video should NOT seek
/// - 'chart': chart tapped/dragged → video should seek; charts should NOT update position
/// - 'scrub_bar': shared bar dragged → both video and charts should update
/// - 'none': no playhead activity yet
final playheadSourceProvider = StateProvider<String>((ref) => 'none');
