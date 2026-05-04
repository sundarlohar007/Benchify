#!/usr/bin/env python3
"""iOS Performance Metrics Collector — Benchify

Streams performance metrics from a connected iOS device via pyidevice.
Outputs one JSON object per second to stdout.

Usage: python3 collector.py <udid> <bundle_id>

Field mapping per UNIFIED-SPEC §5.10.
"""

import json
import signal
import sys
import time

FIELDS = [
    "ts", "fps", "jank", "frametimes", "cpu", "cpu_threads",
    "mem_bytes", "mem_subsections", "bat_pct", "bat_ma", "bat_mv",
    "bat_temp_c", "charging", "charging_source", "wifi",
    "net_tx", "net_rx", "thermal", "gpu_pct"
]

REF_PERIOD = 16.67  # 60Hz default, ms
MAX_FRAMETIMES = 200
RUNNING = True


def handle_sigterm(signum, frame):
    global RUNNING
    RUNNING = False


signal.signal(signal.SIGTERM, handle_sigterm)


class JankTracker:
    """Computes 3-tier jank classification from rolling frame times."""

    def __init__(self, refresh_period=REF_PERIOD):
        self.refresh = refresh_period
        self.window = []  # Last 3 frame times

    def classify(self, frame_times_ms):
        """Classify each frame time into small/medium/big jank."""
        small = jank = big = ratio_jank = 0
        for ft in frame_times_ms:
            self.window.append(ft)
            if len(self.window) > 3:
                self.window.pop(0)
            if len(self.window) >= 2:
                delta = abs(ft - self.window[-2])
                if delta > self.refresh * 4:
                    big += 1
                elif delta > self.refresh * 2.5:
                    jank += 1
                elif delta > self.refresh * 1.5:
                    small += 1
            # Frame ratio jank: frame time / refresh_period
            if ft > self.refresh * 1.3:
                ratio_jank += 1
        return small, jank, big, ratio_jank


def safe_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def safe_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def collect_metrics(udid, bundle_id):
    """Main collection loop. Returns None on failure, streams JSON to stdout."""
    try:
        from py_ios_device import PyiOSDevice
    except ImportError:
        print(json.dumps({
            "error": "pyidevice not installed",
            "help": "pip3 install py-ios-device"
        }))
        sys.exit(1)

    device = PyiOSDevice(udid)
    jank_tracker = JankTracker()

    try:
        # Establish instrument connections
        gpu_available = False
        mem_detail_available = False

        try:
            device.start_instrument("graphics.opengl")
        except Exception:
            pass  # GPU graphics tracking unavailable

        try:
            device.start_instrument("sysmontap")
        except Exception:
            pass  # sysmon unavailable

        try:
            device.start_instrument("memdetail")
            mem_detail_available = True
        except Exception:
            pass

        try:
            device.start_instrument("battery")
        except Exception:
            pass

        try:
            device.start_instrument("networking")
        except Exception:
            pass

        try:
            device.start_instrument("gpu_counters")
            gpu_available = True
        except Exception:
            pass

        prev_net_tx = 0
        prev_net_rx = 0

        while RUNNING:
            ts = int(time.time() * 1000)
            result = {"ts": ts}

            # FPS from graphics.opengl
            try:
                frame_times = device.get_frame_times()
                if frame_times:
                    result["frametimes"] = [round(ft, 2) for ft in frame_times[:MAX_FRAMETIMES]]
                    result["fps"] = round(1000.0 / (sum(frame_times) / len(frame_times)), 1)
                    small, jank, big, ratio = jank_tracker.classify(frame_times)
                    result["jank"] = {"small": small, "jank": jank, "big": big, "ratio": ratio}
                else:
                    result["fps"] = None
                    result["jank"] = {"small": 0, "jank": 0, "big": 0, "ratio": 0}
                    result["frametimes"] = []
            except Exception:
                result["fps"] = None
                result["jank"] = {"small": 0, "jank": 0, "big": 0, "ratio": 0}
                result["frametimes"] = []

            # CPU from sysmontap
            try:
                cpu_data = device.get_sysmon_cpu()
                result["cpu"] = safe_float(cpu_data.get("cpuUsage")) if cpu_data else None
                threads = cpu_data.get("threads", []) if cpu_data else []
                result["cpu_threads"] = sorted(
                    threads, key=lambda t: t.get("pct", 0), reverse=True
                )[:8]
            except Exception:
                result["cpu"] = None
                result["cpu_threads"] = []

            # Memory from sysmontap + memdetail
            try:
                mem_data = device.get_sysmon_mem()
                result["mem_bytes"] = safe_int(mem_data.get("physFootprint")) if mem_data else None
            except Exception:
                result["mem_bytes"] = None

            result["mem_subsections"] = {"app": 0, "other": 0, "total": 0}
            if mem_detail_available:
                try:
                    detail = device.get_mem_detail()
                    if detail:
                        result["mem_subsections"] = {
                            "app": safe_int(detail.get("app", 0)) or 0,
                            "other": safe_int(detail.get("other", 0)) or 0,
                            "total": safe_int(detail.get("total", 0)) or 0,
                        }
                except Exception:
                    pass

            # Battery
            try:
                bat_data = device.get_battery_info()
                if bat_data:
                    result["bat_pct"] = safe_int(bat_data.get("batteryPct"))
                    result["bat_ma"] = safe_float(bat_data.get("batteryCurrent"))
                    result["bat_mv"] = safe_float(bat_data.get("batteryVoltage"))
                    result["bat_temp_c"] = safe_float(bat_data.get("batteryTemp"))
                    state = bat_data.get("batteryState", "")
                    result["charging"] = state in ("charging", "full")
                    result["charging_source"] = state if state else "none"
                else:
                    result["bat_pct"] = None
                    result["bat_ma"] = None
                    result["bat_mv"] = None
                    result["bat_temp_c"] = None
                    result["charging"] = False
                    result["charging_source"] = "none"
            except Exception:
                result["bat_pct"] = None
                result["bat_ma"] = None
                result["bat_mv"] = None
                result["bat_temp_c"] = None
                result["charging"] = False
                result["charging_source"] = "none"

            # WiFi state from processInfo
            try:
                info = device.get_process_info()
                result["wifi"] = bool(info.get("wifi", False)) if info else False
            except Exception:
                result["wifi"] = False

            # Network
            try:
                net_data = device.get_network_stats()
                if net_data:
                    tx = safe_int(net_data.get("tx_bytes", 0)) or 0
                    rx = safe_int(net_data.get("rx_bytes", 0)) or 0
                    result["net_tx"] = tx
                    result["net_rx"] = rx
                else:
                    result["net_tx"] = 0
                    result["net_rx"] = 0
            except Exception:
                result["net_tx"] = 0
                result["net_rx"] = 0

            # Thermal
            try:
                info = device.get_process_info()
                result["thermal"] = safe_int(info.get("thermalState", 0)) if info else 0
            except Exception:
                result["thermal"] = 0

            # GPU
            if gpu_available:
                try:
                    gpu_data = device.get_gpu_counters()
                    result["gpu_pct"] = safe_float(gpu_data.get("gpuPct")) if gpu_data else None
                except Exception:
                    result["gpu_pct"] = None
            else:
                result["gpu_pct"] = None

            print(json.dumps(result), flush=True)
            time.sleep(1.0)

    except Exception as e:
        print(json.dumps({"error": str(e)}), flush=True)
        sys.exit(1)
    finally:
        try:
            device.stop_all()
        except Exception:
            pass
        print(json.dumps({"status": "stopped"}), flush=True)


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 collector.py <udid> <bundle_id>", file=sys.stderr)
        sys.exit(1)

    udid = sys.argv[1]
    bundle_id = sys.argv[2].strip()

    collect_metrics(udid, bundle_id)


if __name__ == "__main__":
    main()
