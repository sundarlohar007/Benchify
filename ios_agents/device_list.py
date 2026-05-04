#!/usr/bin/env python3
"""
iOS Device List (Placeholder — D-01)

Interface contract:
  Lists connected iOS devices and their properties via pyidevice.
  Outputs JSON array of device objects to stdout:
    [{"udid": "...", "name": "...", "os_version": "...", "model": "..."}, ...]

Usage:
  python device_list.py

Implemented in Wave 4 (MVP-17).
"""

import sys
import json


def main():
    # TODO: Discover connected iOS devices via pyidevice
    # TODO: Collect device properties (name, OS version, model, UDID)
    # TODO: Output JSON array to stdout
    pass


if __name__ == '__main__':
    print(json.dumps({
        "interface": "ios_device_list",
        "version": "1.0",
        "output": [
            {"udid": "string", "name": "string", "os_version": "string", "model": "string"}
        ],
        "note": "Placeholder — to be implemented in Wave 4 (MVP-17)"
    }), file=sys.stderr)
    main()
