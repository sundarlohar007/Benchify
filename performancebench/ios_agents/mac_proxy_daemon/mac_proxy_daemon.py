#!/usr/bin/env python3
"""
Mac Proxy Daemon — serves iOS device profiling over local network.
Windows PerformanceBench app connects via HTTP REST + WebSocket.

REST endpoints:
  GET  /devices              -> list connected iOS devices (JSON array)
  GET  /devices/:udid/apps   -> list installed apps (JSON array)
  GET  /ws/metrics?udid=X&bundle_id=Y -> WebSocket upgrade, 1Hz metric stream

Zero-config: Registers _performancebench._tcp via Bonjour/mDNS on port 8589.
No authentication — local network only (per D-08).
"""

import asyncio
import json
import socket
import sys
import time
import argparse
from aiohttp import web

try:
    from zeroconf import ServiceInfo, Zeroconf
    ZEROCONF_AVAILABLE = True
except ImportError:
    ZEROCONF_AVAILABLE = False

try:
    from py_ios_device import PyiOSDevice
    PYIDEVICE_AVAILABLE = True
except ImportError:
    PYIDEVICE_AVAILABLE = False

HOST = '0.0.0.0'
PORT = 8589
SERVICE_TYPE = '_performancebench._tcp.local.'
SERVICE_NAME = 'PerformanceBench Mac Proxy'

active_collectors = {}  # udid -> asyncio.Task


# ── Bonjour/mDNS registration ─────────────────────────────────────────

def get_local_ip():
    """Get the local network IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return '127.0.0.1'


def register_bonjour(port):
    """Register _performancebench._tcp service via Bonjour/mDNS for zero-config discovery."""
    if not ZEROCONF_AVAILABLE:
        print('[mac_proxy] zeroconf not installed — Bonjour disabled. pip install zeroconf')
        return None
    try:
        local_ip = get_local_ip()
        zeroconf = Zeroconf()
        info = ServiceInfo(
            SERVICE_TYPE,
            f'{SERVICE_NAME}.{SERVICE_TYPE}',
            addresses=[socket.inet_aton(local_ip)],
            port=port,
            properties={'version': '1.5', 'platform': 'mac'},
        )
        zeroconf.register_service(info)
        print(f'[mac_proxy] Bonjour registered: {SERVICE_TYPE} on {local_ip}:{port}')
        return zeroconf
    except Exception as e:
        print(f'[mac_proxy] Bonjour registration failed: {e}')
        return None


# ── REST handlers ──────────────────────────────────────────────────────

async def handle_devices(request):
    """GET /devices — list connected iOS devices."""
    if not PYIDEVICE_AVAILABLE:
        return web.json_response({'error': 'pyidevice not installed'}, status=500)
    try:
        device_list = PyiOSDevice.list_devices()
        result = []
        for d in device_list:
            result.append({
                'udid': d.udid if hasattr(d, 'udid') else d.get('udid', ''),
                'name': d.name if hasattr(d, 'name') else d.get('name', 'Unknown'),
                'model': d.model if hasattr(d, 'model') else d.get('model', ''),
                'os_version': d.os_version if hasattr(d, 'os_version') else d.get('os_version', ''),
                'connected': True,
            })
        return web.json_response(result)
    except Exception as e:
        return web.json_response({'error': str(e)}, status=500)


async def handle_apps(request):
    """GET /devices/{udid}/apps — list installed apps."""
    udid = request.match_info['udid']
    if not PYIDEVICE_AVAILABLE:
        return web.json_response({'error': 'pyidevice not installed'}, status=500)
    try:
        device = PyiOSDevice(udid)
        apps = device.list_apps()
        result = []
        for a in apps:
            result.append({
                'bundle_id': a.get('CFBundleIdentifier', ''),
                'name': a.get('CFBundleName', 'Unknown'),
                'version': a.get('CFBundleShortVersionString', ''),
                'build': a.get('CFBundleVersion', ''),
            })
        return web.json_response(result)
    except Exception as e:
        return web.json_response({'error': str(e)}, status=500)


async def handle_ws_metrics(request):
    """GET /ws/metrics?udid=X&bundle_id=Y — WebSocket 1Hz metric stream."""
    udid = request.query.get('udid')
    bundle_id = request.query.get('bundle_id')
    if not udid or not bundle_id:
        return web.json_response({'error': 'udid and bundle_id required'}, status=400)

    ws = web.WebSocketResponse()
    await ws.prepare(request)

    collector_task = asyncio.create_task(_stream_metrics(ws, udid, bundle_id))
    active_collectors[udid] = collector_task

    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                    if data.get('command') == 'stop':
                        break
                except json.JSONDecodeError:
                    pass
            elif msg.type == web.WSMsgType.ERROR:
                break
    finally:
        collector_task.cancel()
        active_collectors.pop(udid, None)
        await ws.close()
    return ws


# ── Metric streaming ───────────────────────────────────────────────────

async def _stream_metrics(ws, udid, bundle_id):
    """Stream 1Hz metrics via WebSocket using pyidevice."""
    try:
        device = PyiOSDevice(udid)

        # Start instruments for each metric source
        graphics_ok = False
        sysmon_ok = False
        battery_ok = False
        network_ok = False
        gpu_ok = False
        memdetail_ok = False

        try:
            device.start_instrument("graphics.opengl")
            graphics_ok = True
        except Exception:
            pass

        try:
            device.start_instrument("sysmontap")
            sysmon_ok = True
        except Exception:
            pass

        try:
            device.start_instrument("battery")
            battery_ok = True
        except Exception:
            pass

        try:
            device.start_instrument("networking")
            network_ok = True
        except Exception:
            pass

        try:
            device.start_instrument("gpu_counters")
            gpu_ok = True
        except Exception:
            pass

        try:
            device.start_instrument("memdetail")
            memdetail_ok = True
        except Exception:
            pass

        while True:
            ts = int(time.time() * 1000)
            sample = {'ts': ts}

            # FPS
            if graphics_ok:
                try:
                    frame_times = device.get_frame_times()
                    if frame_times and len(frame_times) > 0:
                        sample['fps'] = round(1000.0 / (sum(frame_times) / len(frame_times)), 1)
                    else:
                        sample['fps'] = None
                except Exception:
                    sample['fps'] = None
            else:
                sample['fps'] = None

            # CPU
            if sysmon_ok:
                try:
                    cpu_data = device.get_sysmon_cpu()
                    if cpu_data:
                        cpu_usage = cpu_data.get('cpuUsage')
                        if cpu_usage is not None:
                            sample['cpu'] = float(cpu_usage)
                        else:
                            sample['cpu'] = None
                    else:
                        sample['cpu'] = None
                except Exception:
                    sample['cpu'] = None
            else:
                sample['cpu'] = None

            # Memory
            if sysmon_ok:
                try:
                    mem_data = device.get_sysmon_mem()
                    if mem_data:
                        footprint = mem_data.get('physFootprint')
                        if footprint is not None:
                            sample['mem_kb'] = int(footprint) // 1024
                        else:
                            sample['mem_kb'] = None
                    else:
                        sample['mem_kb'] = None
                except Exception:
                    sample['mem_kb'] = None
            else:
                sample['mem_kb'] = None

            # GPU
            if gpu_ok:
                try:
                    gpu_data = device.get_gpu_counters()
                    if gpu_data:
                        gpu_pct = gpu_data.get('gpuPct')
                        sample['gpu_pct'] = float(gpu_pct) if gpu_pct is not None else None
                    else:
                        sample['gpu_pct'] = None
                except Exception:
                    sample['gpu_pct'] = None
            else:
                sample['gpu_pct'] = None

            # Thermal
            try:
                info = device.get_process_info()
                if info:
                    thermal_val = info.get('thermalState', 0)
                    sample['thermal'] = int(thermal_val) if thermal_val is not None else None
                else:
                    sample['thermal'] = None
            except Exception:
                sample['thermal'] = None

            # Battery
            if battery_ok:
                try:
                    bat_data = device.get_battery_info()
                    if bat_data:
                        sample['bat_pct'] = bat_data.get('batteryPct')
                        sample['bat_ma'] = bat_data.get('batteryCurrent')
                        sample['bat_mv'] = bat_data.get('batteryVoltage')
                        sample['bat_temp_c'] = bat_data.get('batteryTemp')
                        state = bat_data.get('batteryState', '')
                        sample['charging'] = state in ('charging', 'full')
                    else:
                        sample['bat_pct'] = None
                        sample['bat_ma'] = None
                        sample['bat_mv'] = None
                        sample['bat_temp_c'] = None
                        sample['charging'] = False
                except Exception:
                    sample['bat_pct'] = None
                    sample['bat_ma'] = None
                    sample['bat_mv'] = None
                    sample['bat_temp_c'] = None
                    sample['charging'] = False
            else:
                sample['bat_pct'] = None
                sample['bat_ma'] = None
                sample['bat_mv'] = None
                sample['bat_temp_c'] = None
                sample['charging'] = False

            # WiFi
            try:
                info = device.get_process_info()
                sample['wifi'] = bool(info.get('wifi', False)) if info else False
            except Exception:
                sample['wifi'] = False

            # Network
            if network_ok:
                try:
                    net_data = device.get_network_stats()
                    if net_data:
                        sample['net_tx'] = net_data.get('tx_bytes', 0)
                        sample['net_rx'] = net_data.get('rx_bytes', 0)
                    else:
                        sample['net_tx'] = 0
                        sample['net_rx'] = 0
                except Exception:
                    sample['net_tx'] = 0
                    sample['net_rx'] = 0
            else:
                sample['net_tx'] = 0
                sample['net_rx'] = 0

            await ws.send_json(sample)
            await asyncio.sleep(1.0)

    except asyncio.CancelledError:
        pass
    except Exception as e:
        try:
            await ws.send_json({'error': str(e)})
        except Exception:
            pass


# ── Main ────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='PerformanceBench Mac Proxy Daemon')
    parser.add_argument('--port', type=int, default=PORT, help='Port to listen on')
    parser.add_argument('--no-bonjour', action='store_true', help='Disable Bonjour/mDNS registration')
    args = parser.parse_args()

    app = web.Application()
    app.router.add_get('/devices', handle_devices)
    app.router.add_get('/devices/{udid}/apps', handle_apps)
    app.router.add_get('/ws/metrics', handle_ws_metrics)

    zc = None
    if not args.no_bonjour:
        zc = register_bonjour(args.port)

    print(f'[mac_proxy] Starting on {HOST}:{args.port}')
    try:
        web.run_app(app, host=HOST, port=args.port)
    finally:
        if zc:
            zc.close()


if __name__ == '__main__':
    main()
