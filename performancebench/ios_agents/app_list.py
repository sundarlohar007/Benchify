#!/usr/bin/env python3
"""List installed third-party apps on an iOS device via installation_proxy.

Usage: python3 app_list.py <udid>
Output: JSON array of app info objects to stdout.
"""

import json
import sys


def list_apps(udid):
    try:
        from py_ios_device import PyiOSDevice
        device = PyiOSDevice(udid)
        apps = device.list_apps()
        result = []
        for app in apps:
            # Filter: only user-installed apps
            app_type = getattr(app, "applicationType", "")
            if app_type and "System" in str(app_type):
                continue
            result.append({
                "bundle_id": app.bundle_id or "",
                "name": app.name or "Unknown",
                "version": getattr(app, "version", "") or "",
                "build": getattr(app, "build", "") or "",
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
    if len(sys.argv) < 2:
        print("Usage: python3 app_list.py <udid>", file=sys.stderr)
        sys.exit(1)
    list_apps(sys.argv[1])
