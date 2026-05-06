#!/usr/bin/env python3
"""
iOS DVT screen-mirror recorder — pymobiledevice3 subprocess.
Usage: python3 dvt_recorder.py <udid> [--quality 1080p|720p|480p] [--fps 30|60|15]
       [--output-dir /tmp] [--session-id SESSION_ID]

Streams DVT screen data from an iOS device, pipes to ffmpeg for H.264 MP4 encoding.
Auto-chunks at 5-minute intervals (same as Android ScreenrecordService per D-17).
Emits JSON status lines to stdout for desktop parsing.

Architecture:
  iOS Device ──[DVT SecureSocket]──> pymobiledevice3 ──[raw BGRA]──> ffmpeg stdin
  ffmpeg ──[H.264 MP4]──> data/videos/<session_id>/<chunk files>
  Status: JSON lines on stdout

Per D-17: Reuses Android ScreenrecordService pattern — start/stop lifecycle,
  same chunk naming, same Video model schema, same VideoTab playback.
Per D-18: macOS-only feature.
Per D-19: Start/stop sync — DVT recording started before first MetricSample,
  stopped after last.
Per D-21: Video-only — no audio capture. ffmpeg uses -an flag.
"""

import sys
import json
import time
import subprocess
import signal
import os
import argparse
import traceback

from dvt_recorder_config import (
    QUALITY_PRESETS, FPS_OPTIONS, CHUNK_DURATION_SECONDS,
    DVT_CONNECT_TIMEOUT, FFMPEG_PRESET, FFMPEG_CRF, FFMPEG_PIX_FMT,
    MAX_CHUNKS,
)

# ---------------------------------------------------------------------------
# Global state for signal handling
# ---------------------------------------------------------------------------
_stopped = False


def _on_sigterm(signum, frame):
    """Handle SIGTERM — gracefully stop after current chunk."""
    global _stopped
    _stopped = True
    print(json.dumps({"event": "signal_received", "signal": signum}), flush=True)


signal.signal(signal.SIGTERM, _on_sigterm)
signal.signal(signal.SIGINT, _on_sigterm)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _emit(event_data: dict):
    """Write a JSON status line to stdout and flush."""
    print(json.dumps(event_data), flush=True)


def _get_lockdown_client(udid: str):
    """
    Create a LockdownClient for the given device UDID.
    Uses pymobiledevice3 to establish the lockdown connection.
    """
    from pymobiledevice3.lockdown import create_using_usbmux
    return create_using_usbmux(serial=udid)


def _encode_chunk(
    width: int,
    height: int,
    fps: int,
    chunk_path: str,
    bitrate: str,
    chunk_duration: int,
) -> subprocess.Popen:
    """
    Spawn ffmpeg subprocess for H.264 MP4 encoding.
    Reads raw BGRA frames from stdin, writes MP4 to chunk_path.

    Per D-21: -an flag for no audio.
    """
    cmd = [
        'ffmpeg', '-y',
        '-f', 'rawvideo',
        '-pixel_format', 'bgra',
        '-video_size', f'{width}x{height}',
        '-framerate', str(fps),
        '-i', 'pipe:0',            # stdin from DVT frames
        '-c:v', 'libx264',
        '-preset', FFMPEG_PRESET,
        '-crf', FFMPEG_CRF,
        '-pix_fmt', FFMPEG_PIX_FMT,
        '-b:v', bitrate,
        '-an',                     # No audio per D-21
        '-t', str(chunk_duration),
        chunk_path,
    ]

    # Redirect stderr to DEVNULL to avoid cluttering stdout JSON stream.
    # Threat mitigation T-04-20: ffmpeg stderr redirected — no sensitive data in process output.
    return subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)


def _record_chunk(
    dvt_service,
    ffmpeg_proc: subprocess.Popen,
    chunk_index: int,
) -> bool:
    """
    Stream DVT frames to ffmpeg stdin until stopped or chunk_complete.
    Returns True if stopped by signal, False if chunk completed normally.
    """
    chunk_start_time = time.time()

    while not _stopped:
        elapsed = time.time() - chunk_start_time

        # Check if chunk duration exceeded
        if elapsed >= CHUNK_DURATION_SECONDS:
            return False  # Chunk completed

        try:
            # Get frame from DVT service
            # DvtSecureSocketProxyService provides screen frames via a callback
            # or a frame generator. We need to poll for frames.
            frame_data = dvt_service.get_next_frame(timeout=1.0)

            if frame_data is None:
                # No frame available yet — continue waiting
                continue

            # Write raw BGRA frame to ffmpeg stdin
            try:
                ffmpeg_proc.stdin.write(frame_data)
            except (BrokenPipeError, OSError):
                # ffmpeg pipe broken — chunk failed
                _emit({
                    "event": "chunk_error",
                    "chunk": chunk_index,
                    "error": "ffmpeg pipe broken",
                })
                return False

        except Exception as e:
            # Frame fetch error — log and continue
            _emit({
                "event": "chunk_warning",
                "chunk": chunk_index,
                "warning": str(e),
            })
            continue

    return True  # Stopped by signal


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="iOS DVT screen-mirror recorder"
    )
    parser.add_argument('udid', help='iOS device UDID')
    parser.add_argument(
        '--quality', default='1080p',
        choices=list(QUALITY_PRESETS.keys()),
        help='Video quality preset (default: 1080p)'
    )
    parser.add_argument(
        '--fps', type=int, default=30,
        choices=FPS_OPTIONS,
        help='Frame rate (default: 30)'
    )
    parser.add_argument(
        '--output-dir', default='data/videos',
        help='Output directory for video chunks (default: data/videos)'
    )
    parser.add_argument(
        '--session-id', required=True,
        help='Session ID for chunk file naming'
    )
    args = parser.parse_args()

    # Validate quality preset
    if args.quality not in QUALITY_PRESETS:
        _emit({
            "event": "fatal_error",
            "error": f"Invalid quality: {args.quality}. Choose from: {list(QUALITY_PRESETS.keys())}"
        })
        sys.exit(1)

    preset = QUALITY_PRESETS[args.quality]
    width = preset['width']
    height = preset['height']
    bitrate = preset['bitrate']
    fps = args.fps
    output_dir = os.path.join(args.output_dir, args.session_id)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Announce recording start
    _emit({
        "event": "recording_started",
        "session_id": args.session_id,
        "width": width,
        "height": height,
        "fps": fps,
        "quality": args.quality,
        "bitrate": bitrate,
        "output_dir": output_dir,
    })

    # Connect to the iOS device via DVT
    try:
        lockdown = _get_lockdown_client(args.udid)
    except Exception as e:
        _emit({
            "event": "fatal_error",
            "error": f"Failed to connect to device {args.udid}: {e}",
        })
        sys.exit(1)

    try:
        from pymobiledevice3.services.dvt.dvt_secure_socket_proxy import DvtSecureSocketProxyService

        with DvtSecureSocketProxyService(lockdown=lockdown) as dvt_service:
            chunk_index = 0

            while not _stopped and chunk_index < MAX_CHUNKS:
                chunk_index += 1
                chunk_file = f"{args.session_id}_chunk_{chunk_index:03d}.mp4"
                chunk_path = os.path.join(output_dir, chunk_file)

                chunk_start_ms = int(time.time() * 1000)
                _emit({
                    "event": "chunk_start",
                    "chunk": chunk_index,
                    "file": chunk_file,
                    "timestamp_ms": chunk_start_ms,
                })

                # Start ffmpeg for this chunk
                ffmpeg_proc = _encode_chunk(
                    width, height, fps, chunk_path, bitrate, CHUNK_DURATION_SECONDS
                )

                # Record frames
                stopped_by_signal = _record_chunk(dvt_service, ffmpeg_proc, chunk_index)

                # Close ffmpeg stdin and wait
                try:
                    ffmpeg_proc.stdin.close()
                except (BrokenPipeError, OSError):
                    pass

                try:
                    ffmpeg_proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    ffmpeg_proc.kill()
                    ffmpeg_proc.wait()

                # Report chunk end
                chunk_end_ms = int(time.time() * 1000)
                try:
                    file_size = os.path.getsize(chunk_path) if os.path.exists(chunk_path) else 0
                except OSError:
                    file_size = 0

                _emit({
                    "event": "chunk_end",
                    "chunk": chunk_index,
                    "file": chunk_file,
                    "timestamp_ms": chunk_end_ms,
                    "size_bytes": file_size,
                    "stopped": stopped_by_signal,
                })

                if stopped_by_signal:
                    break

    except ImportError:
        _emit({
            "event": "fatal_error",
            "error": "pymobiledevice3 is not installed. Install with: pip3 install pymobiledevice3"
        })
        sys.exit(1)
    except Exception as e:
        _emit({
            "event": "fatal_error",
            "error": str(e),
            "traceback": traceback.format_exc(),
        })
        sys.exit(1)

    # Final status
    _emit({
        "event": "recording_stopped",
        "session_id": args.session_id,
        "total_chunks": chunk_index,
    })


if __name__ == '__main__':
    main()
