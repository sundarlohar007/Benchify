#!/usr/bin/env python3
"""tidevice-based iOS metric collector for Windows.
Collects ~8 metrics at 1Hz, streams newline-delimited JSON to stdout.
Documented gaps: GPU%, thermal status, battery mA/mV unavailable via tidevice.
"""

import json
import sys
import time
import argparse

try:
    from tidevice import Device, InstrumentsService, DeviceInfo
    TIDEVICE_AVAILABLE = True
except ImportError:
    TIDEVICE_AVAILABLE = False


def collect_metrics(udid, bundle_id):
    """Stream metrics at 1Hz from tidevice."""
    if not TIDEVICE_AVAILABLE:
        sys.stdout.write(json.dumps({
            "error": "tidevice not installed",
            "help": "pip install tidevice"
        }) + '\n')
        sys.stdout.flush()
        return

    try:
        device = Device(udid=udid)
        info = DeviceInfo(device)

        # Start Instruments service for FPS and CPU
        instruments = InstrumentsService(device)

        sample_count = 0
        try:
            while True:
                ts = int(time.time() * 1000)

                # FPS — via Graphics instrument
                fps = None
                try:
                    graphics_data = instruments.get_graphics_fps()
                    if graphics_data:
                        fps = graphics_data.get('fps')
                except Exception:
                    pass

                # CPU — system CPU from Instruments
                cpu = None
                try:
                    cpu_data = instruments.get_process_cpu()
                    if cpu_data:
                        cpu = cpu_data.get('cpu_usage')  # percentage
                except Exception:
                    pass

                # Memory — physical footprint
                memory_kb = None
                try:
                    mem_info = device.memory_info()
                    if mem_info:
                        memory_bytes = mem_info.get('physical_footprint')
                        if memory_bytes:
                            memory_kb = memory_bytes // 1024
                except Exception:
                    pass

                # Battery % (available on tidevice)
                battery_pct = None
                try:
                    bat_info = device.battery_info()
                    if bat_info:
                        battery_pct = bat_info.get('level')  # 0-100
                except Exception:
                    pass

                # Network — cumulative bytes (limited on tidevice)
                net_tx = None
                net_rx = None
                try:
                    net_info = device.network_info()
                    if net_info:
                        net_tx = net_info.get('bytes_sent')
                        net_rx = net_info.get('bytes_received')
                except Exception:
                    pass

                sample = {
                    'ts': ts,
                    'fps': fps,
                    'cpu': cpu,
                    'mem_kb': memory_kb,
                    'bat_pct': battery_pct,
                    'net_tx': net_tx,
                    'net_rx': net_rx,
                    # Documented gaps (always null from tidevice):
                    'gpu_pct': None,
                    'thermal': None,
                    'bat_ma': None,
                    'bat_mv': None,
                    'bat_temp_c': None,
                }

                sys.stdout.write(json.dumps(sample) + '\n')
                sys.stdout.flush()
                time.sleep(1.0)
                sample_count += 1

        except KeyboardInterrupt:
            pass
        finally:
            # Send stop signal
            sys.stdout.write(json.dumps({'status': 'stopped'}) + '\n')
            sys.stdout.flush()

    except Exception as e:
        sys.stdout.write(json.dumps({"error": str(e)}) + '\n')
        sys.stdout.flush()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('udid')
    parser.add_argument('bundle_id')
    args = parser.parse_args()
    collect_metrics(args.udid, args.bundle_id)
