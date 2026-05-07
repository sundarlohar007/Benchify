# SPDX-License-Identifier: MIT
# Copyright (c) 2024 PerformanceBench Contributors
#!/usr/bin/env python3
"""
iOS Metrics Collector (Placeholder — D-01)

Interface contract (UNIFIED-SPEC §5.10):
  Streams newline-delimited JSON to stdout, one object per second.
  Each JSON object contains these keys:
    fps, jank.small, jank.jank, jank.big, cpu, mem_bytes,
    bat_pct, bat_ma, bat_mv, bat_temp_c, net_tx, net_rx,
    thermal, gpu_pct

Usage:
  python collector.py --udid <device_udid>

Implemented in Wave 4 (MVP-17).
"""

import sys
import json


def main():
    # TODO: Parse CLI args (--udid)
    # TODO: Connect to iOS device via pyidevice
    # TODO: Initialize metric collection loop (1 Hz)
    # TODO: Collect and emit metrics as JSON lines
    pass


if __name__ == '__main__':
    # Print interface contract as JSON comment for discovery
    print(json.dumps({
        "interface": "ios_metrics_collector",
        "version": "1.0",
        "keys": [
            "fps", "jank.small", "jank.jank", "jank.big",
            "cpu", "mem_bytes", "bat_pct", "bat_ma", "bat_mv",
            "bat_temp_c", "net_tx", "net_rx", "thermal", "gpu_pct"
        ],
        "note": "Placeholder — to be implemented in Wave 4 (MVP-17)"
    }), file=sys.stderr)
    main()
