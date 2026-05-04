#!/usr/bin/env python3
"""
iOS App List (Placeholder — D-01)

Interface contract:
  Lists installed applications on a connected iOS device.
  Outputs JSON array of app objects to stdout:
    [{"bundle_id": "...", "name": "...", "version": "...", "build": "..."}, ...]

Usage:
  python app_list.py --udid <device_udid>

Implemented in Wave 4 (MVP-17).
"""

import sys
import json


def main():
    # TODO: Parse CLI args (--udid)
    # TODO: Connect to iOS device via pyidevice
    # TODO: Enumerate installed apps
    # TODO: Output JSON array to stdout
    pass


if __name__ == '__main__':
    print(json.dumps({
        "interface": "ios_app_list",
        "version": "1.0",
        "output": [
            {"bundle_id": "string", "name": "string", "version": "string", "build": "string"}
        ],
        "note": "Placeholder — to be implemented in Wave 4 (MVP-17)"
    }), file=sys.stderr)
    main()
