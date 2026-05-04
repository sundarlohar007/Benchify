#!/usr/bin/env python3
"""List connected iOS devices via pyidevice.

Usage: python3 device_list.py
Output: JSON array of device objects to stdout.
"""

import json
import sys


def list_devices():
    try:
        from py_ios_device import PyiOSDevice
        devices = PyiOSDevice.list_devices()
        result = []
        for d in devices:
            result.append({
                "udid": d.udid or "",
                "name": d.name or "Unknown",
                "model": d.model or "",
                "os_version": d.os_version or "",
                "connected": getattr(d, "connected", True),
            })
        print(json.dumps(result))
    except ImportError:
        print(json.dumps({
            "error": "pyidevice not installed",
            "help": "pip3 install py-ios-device"
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    list_devices()
