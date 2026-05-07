# SPDX-License-Identifier: MIT
# Copyright (c) 2024 PerformanceBench Contributors
#!/usr/bin/env python3
"""
Shared config constants for DVT screen recording.
Per D-20: Configurable video quality options.

Usage:
  from dvt_recorder_config import QUALITY_PRESETS, FPS_OPTIONS, CHUNK_DURATION_SECONDS
"""

# Resolution and quality presets per D-20
QUALITY_PRESETS = {
    '480p': {'width': 640, 'height': 480, 'bitrate': '2M'},
    '720p': {'width': 1280, 'height': 720, 'bitrate': '4M'},
    '1080p': {'width': 1920, 'height': 1080, 'bitrate': '8M'},
}

FPS_OPTIONS = [15, 30, 60]
CHUNK_DURATION_SECONDS = 300  # 5 minutes per D-17
OUTPUT_CODEC = 'h264'
OUTPUT_CONTAINER = 'mp4'

# Maximum number of chunks before auto-stop (24 hours at 5-min chunks)
MAX_CHUNKS = 288

# DVT connection timeout in seconds
DVT_CONNECT_TIMEOUT = 10

# ffmpeg encoder settings
FFMPEG_PRESET = 'ultrafast'
FFMPEG_CRF = '23'
FFMPEG_PIX_FMT = 'yuv420p'
