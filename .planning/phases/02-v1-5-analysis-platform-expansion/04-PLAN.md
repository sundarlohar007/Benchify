---
phase: 02-v1-5-analysis-platform-expansion
plan: 04
type: execute
wave: 4
depends_on:
  - 03
files_modified:
  - performancebench/lib/core/services/tidevice_service.dart
  - ios_agents/tidevice_collector.py
  - ios_agents/mac_proxy_daemon/mac_proxy_daemon.py
  - ios_agents/mac_proxy_daemon/requirements.txt
  - performancebench/lib/core/services/mac_proxy_service.dart
  - performancebench/lib/core/services/ios_service.dart
  - performancebench/lib/core/collector/metric_collector.dart
  - test/core/services/tidevice_service_test.dart
  - test/core/services/mac_proxy_service_test.dart
autonomous: true
requirements:
  - V15-08
  - V15-09
  - V15-10

must_haves:
  truths:
    - "Windows user can discover and profile iOS devices via tidevice with ~8 metrics (documented gaps for GPU, thermal, battery current)"
    - "Windows user can profile iOS devices with full metrics via Mac proxy daemon on local network"
    - "Mac proxy daemon auto-discovered via Bonjour/mDNS — zero configuration required"
    - "Linux app launches, discovers ADB devices, and completes a 60-second profiling session"
  artifacts:
    - path: "performancebench/lib/core/services/tidevice_service.dart"
      provides: "tidevice-based iOS profiling on Windows — subprocess management for tidevice CLI"
      exports: ["TideviceService", "start", "stop", "discoverDevices"]
      min_lines: 100
    - path: "ios_agents/mac_proxy_daemon/mac_proxy_daemon.py"
      provides: "Python daemon running on Mac — HTTP REST for device listing, WebSocket for 1Hz metric stream"
      contains: ["device_list endpoint", "app_list endpoint", "ws/metrics WebSocket"]
      min_lines: 120
    - path: "performancebench/lib/core/services/mac_proxy_service.dart"
      provides: "Bonjour/mDNS discovery + HTTP REST client + WebSocket metric stream receiver"
      exports: ["MacProxyService", "MacProxyDevice", "discoverProxy"]
      min_lines: 150
  key_links:
    - from: "mac_proxy_service.dart discoverProxy()"
      to: "mac_proxy_daemon.py mDNS registration"
      via: "Bonjour _performancebench._tcp service type"
      pattern: "multicast_dns.*_performancebench"
    - from: "mac_proxy_service.dart WebSocket stream"
      to: "metric_collector.dart iOS stream path"
      via: "Same Stream<MetricSample> pattern as IosService.start()"
      pattern: "Stream<MetricSample>.*start"
    - from: "tidevice_service.dart start()"
      to: "tidevice_collector.py subprocess"
      via: "Process.start pattern from IosService"
      pattern: "Process\\.start.*tidevice"
</objective>

<objective>
Platform expansion: tidevice on Windows for iOS (~8 metrics, documented gaps), Mac proxy daemon for full iOS metrics via local network, and Linux first-class smoke test.

Purpose: Enables Windows users to profile iOS devices (primary path: Mac proxy daemon with full metrics; fallback: tidevice with subset). Validates Linux as a first-class host platform.

Output: TideviceService, mac_proxy_daemon.py, MacProxyService, Linux smoke test script and results.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-v1-5-analysis-platform-expansion/02-CONTEXT.md

### Spec references (MUST READ during execution)
@performancebench/lib/core/services/ios_service.dart (subprocess pattern reference — Process.start, stdout LineSplitter, SIGTERM/SIGKILL lifecycle)
@performancebench/lib/core/collector/metric_collector.dart (iOS stream integration point)
@performancebench/lib/core/models/metric_sample.dart (all fields — tidevice maps subset, Mac proxy maps all)

### Phase 2 CONTEXT decisions
- D-08: Mac proxy daemon as primary path — HTTP REST + WebSocket, zero-config via Bonjour/mDNS
- D-09: tidevice as documented fallback — ~8 metrics with documented gaps
- Claude's Discretion: REST endpoints, WebSocket message format, authentication (none — local network only)
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: tidevice on Windows for iOS (V15-08)</name>
  <files>
    performancebench/lib/core/services/tidevice_service.dart
    ios_agents/tidevice_collector.py
    test/core/services/tidevice_service_test.dart
  </files>

  <read_first>
  - Read `performancebench/lib/core/services/ios_service.dart` (full IosService class — reuse Process.start pattern, stream parsing, SIGTERM/SIGKILL lifecycle)
  - Read `performancebench/lib/core/models/metric_sample.dart` (all 48 fields — tidevice maps a SUBSET, leaving GPU/thermal/battery_current null)
  - Read Phase 2 CONTEXT.md D-08, D-09 (tidevice as fallback, ~8 metrics, documented gaps)
  - Read `UNIFIED-SPEC.md` lines 996-1004 (§5.10 iOS via pyidevice — same subprocess pattern applies to tidevice)
  - Note: tidevice CLI is a Python package (`pip install tidevice`) — same `python3 -m tidevice` invocation pattern as pyidevice
  </read_first>

  <behavior>
    Tidevice service test expectations (tidevice_service_test.dart):
    Test 1: Platform guard — TideviceService.isSupported returns true on Windows (unlike IosService which is macOS-only)
    Test 2: discoverDevices() parses `tidevice list --json` output correctly — returns list of IosDevice objects
    Test 3: start(udid, bundleId) spawns tidevice_collector.py subprocess, receives newline-delimited JSON on stdout
    Test 4: Valid JSON line → MetricSample emitted on stream with fields: fps, cpuAppPct, memoryPssKb, batteryPct
    Test 5: tidevice sample JSON lacks GPU, thermal, battery current → MetricSample has null for gpuPct, thermalStatus, batteryMa
    Test 6: Malformed JSON line → silently skipped, stream continues (per §5.10: "Lines that fail JSON parsing are silently skipped")
    Test 7: stop() sends SIGTERM, waits 3s, then SIGKILL — same lifecycle as IosService
    Test 8: Process exits with non-zero code → stream closes cleanly, no crash
  </behavior>

  <action>
  **Create `ios_agents/tidevice_collector.py`** — Python script for tidevice-based iOS metric collection on Windows:

  ```python
  #!/usr/bin/env python3
  """tidevice-based iOS metric collector for Windows.
  Collects ~8 metrics at 1Hz, streams newline-delimited JSON to stdout.
  Documented gaps: GPU%, thermal status, battery mA/mV unavailable via tidevice.
  """

  import json
  import sys
  import time
  import argparse
  from tidevice import Device, InstrumentsService, DeviceInfo

  def collect_metrics(udid: str, bundle_id: str):
      """Stream metrics at 1Hz from tidevice."""
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

  if __name__ == '__main__':
      parser = argparse.ArgumentParser()
      parser.add_argument('udid')
      parser.add_argument('bundle_id')
      args = parser.parse_args()
      collect_metrics(args.udid, args.bundle_id)
  ```

  **Create `performancebench/lib/core/services/tidevice_service.dart`** (reusing IosService subprocess pattern):

  ```dart
  import 'dart:async';
  import 'dart:convert';
  import 'dart:io' show Platform, Process, ProcessSignal;
  import '../models/metric_sample.dart';
  import 'ios_service.dart'; // For IosDevice, IosAppInfo models

  /// Manages tidevice subprocess for iOS profiling on Windows.
  ///
  /// Follows same subprocess lifecycle as IosService (Process.start, LineSplitter,
  /// SIGTERM/SIGKILL). tidevice provides ~8 metrics with documented gaps for
  /// GPU%, thermal status, battery mA/mV (per D-09).
  class TideviceService {
    final String python3Path;
    final String agentsDir;

    Process? _process;
    StreamController<MetricSample>? _controller;
    bool _stopped = false;

    TideviceService({
      this.python3Path = 'python3',
      required this.agentsDir,
    });

    /// tidevice works on all platforms (Windows, macOS, Linux).
    static bool get isSupported => true; // Different from IosService (macOS-only)

    /// Discover connected iOS devices via tidevice.
    Future<List<IosDevice>> discoverDevices() async {
      try {
        final result = await Process.run(
          python3Path,
          ['-m', 'tidevice', 'list', '--json'],
        );
        if (result.exitCode != 0) return [];
        final json = jsonDecode(result.stdout as String);
        if (json is! List) return [];
        return json.map((e) => IosDevice.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }

    /// List installed third-party apps on a device via tidevice.
    Future<List<IosAppInfo>> listApps(String udid) async {
      try {
        final result = await Process.run(
          python3Path,
          ['-m', 'tidevice', '--udid', udid, 'applist', '--json'],
        );
        if (result.exitCode != 0) return [];
        final json = jsonDecode(result.stdout as String);
        if (json is! List) return [];
        return json.map((e) => IosAppInfo.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }

    /// Start streaming iOS metrics from tidevice_collector.py.
    /// Returns broadcast Stream<MetricSample> — same interface as IosService.
    Stream<MetricSample> start(String udid, String bundleId) {
      _controller = StreamController<MetricSample>.broadcast();
      _stopped = false;
      _spawnCollector(udid, bundleId);
      return _controller!.stream;
    }

    Future<void> _spawnCollector(String udid, String bundleId) async {
      try {
        _process = await Process.start(
          python3Path,
          ['$agentsDir/tidevice_collector.py', udid, bundleId],
        );

        _process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(_onLine, onDone: () => _controller?.close());

        _process!.stderr.transform(utf8.decoder).listen((line) {
          print('[tidevice_service stderr] $line');
        });

        _process!.exitCode.then((code) {
          if (code != 0 && !_stopped) {
            _controller?.addError('tidevice collector exited with code $code');
          }
          _controller?.close();
        });
      } catch (e) {
        _controller?.addError(e);
        _controller?.close();
      }
    }

    /// Parse JSON line from tidevice_collector.py stdout.
    void _onLine(String line) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json.containsKey('error')) { _controller?.addError(json['error']); stop(); return; }
        if (json['status'] == 'stopped') { stop(); return; }

        final ts = json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final sample = MetricSample(
          sessionId: '',
          timestamp: ts,
          fps: (json['fps'] as num?)?.toDouble(),
          cpuAppPct: (json['cpu'] as num?)?.toDouble(),
          memoryPssKb: json['mem_kb'] as int?,
          batteryPct: json['bat_pct'] as int?,
          netTxBytes: json['net_tx'] as int?,
          netRxBytes: json['net_rx'] as int?,
          // Documented gaps from tidevice (D-09):
          gpuPct: null,
          thermalStatus: null,
          batteryMa: null,
          batteryMv: null,
          batteryTempC: null,
          gpuFreqMhz: null,
          gpuMemKb: null,
        );
        _controller?.add(sample);
      } catch (_) {
        // Malformed JSON — skip (per §5.10)
      }
    }

    void stop() {
      _stopped = true;
      if (_process != null) {
        _process!.kill(ProcessSignal.sigterm);
        Future.delayed(const Duration(seconds: 3), () {
          if (_process != null) _process!.kill(ProcessSignal.sigkill);
          _process = null;
        });
      }
      _controller?.close();
      _controller = null;
    }
  }
  ```

  **Integrate into device discovery flow:**
  Update the device list screen to:
  - On Windows: show both Android (ADB) and iOS (tidevice) devices
  - On macOS: show Android (ADB) and iOS (IosService/pyidevice) — existing behavior
  - Tidevice devices have an "(iOS — limited)" badge with tooltip listing documented gaps

  **Create test** (`test/core/services/tidevice_service_test.dart`):
  - Test all 8 behavior cases above
  - Mock Process.run for discoverDevices / listApps
  - Test MetricSample field mapping with sample tidevice JSON
  - Verify null fields for documented gaps

  After tests pass, commit: `docs(02-04): add tidevice on Windows for iOS profiling (~8 metrics)`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/services/tidevice_service_test.dart</automated>
  </verify>

  <done>
  - TideviceService works on all platforms (not macOS-only)
  - tidevice_collector.py streams ~8 metrics (FPS, CPU, Memory, Battery%, Network TX/RX) at 1Hz
  - GPU, thermal, battery current/mV fields are null per documented gaps
  - Subprocess lifecycle matches IosService pattern (Process.start, SIGTERM/SIGKILL)
  - 8 test cases pass
  </done>
</task>

<task type="auto">
  <name>Task 2: Mac proxy daemon + MacProxyService (V15-09)</name>
  <files>
    ios_agents/mac_proxy_daemon/mac_proxy_daemon.py
    ios_agents/mac_proxy_daemon/requirements.txt
    performancebench/lib/core/services/mac_proxy_service.dart
    performancebench/lib/core/collector/metric_collector.dart
    test/core/services/mac_proxy_service_test.dart
  </files>

  <read_first>
  - Read `performancebench/lib/core/services/ios_service.dart` (subprocess lifecycle reference)
  - Read `performancebench/lib/core/models/metric_sample.dart` (all 48 fields — Mac proxy provides ALL fields)
  - Read Phase 2 CONTEXT.md D-08 (Mac proxy daemon: HTTP REST + WebSocket, zero-config Bonjour/mDNS, local network only, no auth)
  - Read `performancebench/lib/core/collector/metric_collector.dart` (integrate MacProxyService stream as alternative iOS source)
  - Claude's discretion: REST endpoints, WebSocket message format, mDNS service type
  </read_first>

  <action>
  **Create `ios_agents/mac_proxy_daemon/mac_proxy_daemon.py`** (per D-08):

  A Python daemon that runs on the Mac, connects to iOS devices via pyidevice, and serves metrics over HTTP REST + WebSocket to the Windows app on the local network.

  Requirements: `aiohttp`, `zeroconf` (for Bonjour/mDNS), `pyidevice`

  ```python
  #!/usr/bin/env python3
  """
  Mac Proxy Daemon — serves iOS device profiling over local network.
  Windows PerformanceBench app connects via HTTP REST + WebSocket.

  REST endpoints:
    GET  /devices           → list connected iOS devices (JSON array)
    GET  /devices/:udid/apps → list installed apps (JSON array)
    GET  /ws/metrics?udid=X&bundle_id=Y → WebSocket upgrade, 1Hz metric stream

  Zero-config: Registers _performancebench._tcp via Bonjour/mDNS on port 8589.
  No authentication — local network only.
  """

  import asyncio
  import json
  import sys
  import time
  import argparse
  from aiohttp import web
  from zeroconf import ServiceInfo, Zeroconf

  # Dynamic imports — will be resolved when running on Mac with pyidevice
  try:
      from pyidevice import Device, list_devices
      from pyidevice.services.installation_proxy import InstallationProxyService
      PYIDEVICE_AVAILABLE = True
  except ImportError:
      PYIDEVICE_AVAILABLE = False

  HOST = '0.0.0.0'
  PORT = 8589
  SERVICE_TYPE = '_performancebench._tcp.local.'
  SERVICE_NAME = 'PerformanceBench Mac Proxy'

  active_collectors = {}  # udid → asyncio.Task


  # ── REST handlers ────────────────────────────────────────────────

  async def handle_devices(request):
      """GET /devices — list connected iOS devices."""
      if not PYIDEVICE_AVAILABLE:
          return web.json_response({'error': 'pyidevice not installed'}, status=500)
      try:
          devices = list_devices()
          result = [{'udid': d.udid, 'name': d.name, 'model': d.model,
                      'os_version': d.os_version, 'connected': True}
                    for d in devices]
          return web.json_response(result)
      except Exception as e:
          return web.json_response({'error': str(e)}, status=500)


  async def handle_apps(request):
      """GET /devices/{udid}/apps — list installed apps."""
      udid = request.match_info['udid']
      if not PYIDEVICE_AVAILABLE:
          return web.json_response({'error': 'pyidevice not installed'}, status=500)
      try:
          device = Device(udid=udid)
          proxy = InstallationProxyService(device)
          apps = proxy.get_apps()
          result = [{'bundle_id': a.get('CFBundleIdentifier', ''),
                      'name': a.get('CFBundleName', 'Unknown'),
                      'version': a.get('CFBundleShortVersionString', ''),
                      'build': a.get('CFBundleVersion', '')}
                    for a in apps if a.get('CFBundleIdentifier')]
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

      # Start collector for this device
      collector_task = asyncio.create_task(_stream_metrics(ws, udid, bundle_id))
      active_collectors[udid] = collector_task

      try:
          async for msg in ws:
              if msg.type == web.WSMsgType.TEXT:
                  data = json.loads(msg.data)
                  if data.get('command') == 'stop':
                      break
              elif msg.type == web.WSMsgType.ERROR:
                  break
      finally:
          collector_task.cancel()
          active_collectors.pop(udid, None)
          await ws.close()
      return ws


  async def _stream_metrics(ws, udid, bundle_id):
      """Stream 1Hz metrics via WebSocket using pyidevice Instruments."""
      try:
          device = Device(udid=udid)

          # Start Instruments services
          graphics = device.connect_instruments('Graphics')
          cpu = device.connect_instruments('CPU')
          activity = device.connect_instruments('ActivityMonitor')

          while True:
              ts = int(time.time() * 1000)

              sample = {
                  'ts': ts,
                  'fps': _get_graphics_fps(graphics),
                  'cpu': _get_cpu_pct(cpu),
                  'mem_kb': _get_memory_kb(activity),
                  'gpu_pct': _get_gpu_pct(graphics),
                  'thermal': _get_thermal(device),
                  'bat_pct': _get_battery_pct(device),
                  'bat_ma': _get_battery_ma(device),
                  'bat_mv': _get_battery_mv(device),
                  'bat_temp_c': _get_battery_temp(device),
                  'wifi': _get_wifi_active(device),
                  'net_tx': _get_net_tx(device),
                  'net_rx': _get_net_rx(device),
                  'charging': _get_charging(device),
              }

              await ws.send_json(sample)
              await asyncio.sleep(1.0)

      except asyncio.CancelledError:
          pass
      except Exception as e:
          await ws.send_json({'error': str(e)})


  # ── Metric helpers (implement with pyidevice APIs) ────────────────
  # Each helper returns None if metric unavailable (never fabricates)

  def _get_graphics_fps(graphics): ...
  def _get_cpu_pct(cpu): ...
  def _get_memory_kb(activity): ...
  def _get_gpu_pct(graphics): ...
  def _get_thermal(device): ...
  def _get_battery_pct(device): ...
  def _get_battery_ma(device): ...
  def _get_battery_mv(device): ...
  def _get_battery_temp(device): ...
  def _get_wifi_active(device): ...
  def _get_net_tx(device): ...
  def _get_net_rx(device): ...
  def _get_charging(device): ...

  # ── Bonjour/mDNS registration ─────────────────────────────────────

  def register_bonjour():
      """Register _performancebench._tcp service via Bonjour/mDNS for zero-config discovery."""
      zeroconf = Zeroconf()
      info = ServiceInfo(
          SERVICE_TYPE,
          f'{SERVICE_NAME}.{SERVICE_TYPE}',
          addresses=[...],  # local IP
          port=PORT,
          properties={'version': '1.5', 'platform': 'mac'},
      )
      zeroconf.register_service(info)
      return zeroconf


  # ── Main ──────────────────────────────────────────────────────────

  def main():
      parser = argparse.ArgumentParser()
      parser.add_argument('--port', type=int, default=PORT)
      parser.add_argument('--no-bonjour', action='store_true')
      args = parser.parse_args()

      app = web.Application()
      app.router.add_get('/devices', handle_devices)
      app.router.add_get('/devices/{udid}/apps', handle_apps)
      app.router.add_get('/ws/metrics', handle_ws_metrics)

      if not args.no_bonjour:
          zc = register_bonjour()
          print(f'[mac_proxy] Bonjour registered: {SERVICE_TYPE} on port {args.port}')

      print(f'[mac_proxy] Starting on {HOST}:{args.port}')
      web.run_app(app, host=HOST, port=args.port)

  if __name__ == '__main__':
      main()
  ```

  **Create `requirements.txt`:**
  ```
  aiohttp>=3.9.0
  zeroconf>=0.130.0
  pyidevice>=0.0.0
  ```

  **Create `performancebench/lib/core/services/mac_proxy_service.dart`** (per D-08):

  ```dart
  import 'dart:async';
  import 'dart:convert';
  import 'dart:io' show WebSocket;
  import 'package:http/http.dart' as http;
  import '../models/metric_sample.dart';

  /// Represents a discovered Mac proxy daemon on the local network.
  class MacProxyInfo {
    final String host;      // IP address
    final int port;         // Default 8589
    final String name;      // Bonjour service name
    final String version;   // '1.5'

    const MacProxyInfo({required this.host, this.port = 8589, this.name = '', this.version = '1.5'});

    Uri get baseUri => Uri.parse('http://$host:$port');
  }

  /// Manages connection to Mac proxy daemon for full-metrics iOS profiling.
  ///
  /// Discovery: Bonjour/mDNS for _performancebench._tcp service (zero-config per D-08).
  /// Communication: HTTP REST for device/app listing, WebSocket for 1Hz metric stream.
  /// No authentication — local network only.
  class MacProxyService {
    MacProxyInfo? _proxyInfo;
    WebSocket? _ws;
    StreamController<MetricSample>? _controller;
    bool _stopped = false;

    /// Whether the current platform supports Mac proxy (all platforms — proxy handles iOS).
    static bool get isSupported => true;

    /// Discover Mac proxy daemon on local network via mDNS/Bonjour.
    /// Returns list of discovered MacProxyInfo. Empty if none found.
    /// Claude's discretion: Implementation can use multicast_dns package or
    /// platform-specific mDNS queries (dns-sd on macOS, avahi-browse on Linux, etc.)
    Future<List<MacProxyInfo>> discoverProxies() async {
      final proxies = <MacProxyInfo>[];

      try {
        // Attempt mDNS discovery via multicast_dns package
        // Service type: _performancebench._tcp
        // Fallback: allow user to manually enter Mac IP in Settings

        // TODO: Implement actual mDNS query
        // This is a placeholder for the mDNS discovery logic.
        // On macOS: use `dns-sd -B _performancebench._tcp`
        // On Windows: use multicast_dns Dart package
        // On Linux: use `avahi-browse -t _performancebench._tcp`
      } catch (_) {
        // mDNS discovery failed — user can configure manually
      }

      return proxies;
    }

    /// Manually configure proxy address (fallback when mDNS fails).
    void configure(String host, {int port = 8589}) {
      _proxyInfo = MacProxyInfo(host: host, port: port);
    }

    /// List iOS devices connected to the Mac.
    Future<List<dynamic>> discoverDevices() async {
      if (_proxyInfo == null) return [];
      try {
        final response = await http.get(
          Uri.parse('${_proxyInfo!.baseUri}/devices'),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) return [];
        final json = jsonDecode(response.body);
        return json as List<dynamic>;
      } catch (_) {
        return [];
      }
    }

    /// List installed apps on a device connected to the Mac.
    Future<List<dynamic>> listApps(String udid) async {
      if (_proxyInfo == null) return [];
      try {
        final response = await http.get(
          Uri.parse('${_proxyInfo!.baseUri}/devices/$udid/apps'),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) return [];
        final json = jsonDecode(response.body);
        return json as List<dynamic>;
      } catch (_) {
        return [];
      }
    }

    /// Start WebSocket metric stream from Mac proxy daemon.
    /// Returns broadcast Stream<MetricSample> — full metrics (all fields populated).
    Stream<MetricSample> start(String udid, String bundleId) {
      if (_proxyInfo == null) {
        throw StateError('No Mac proxy configured. Call discoverProxies() or configure() first.');
      }

      _controller = StreamController<MetricSample>.broadcast();
      _stopped = false;
      _connectWebSocket(udid, bundleId);
      return _controller!.stream;
    }

    Future<void> _connectWebSocket(String udid, String bundleId) async {
      try {
        final wsUri = Uri.parse(
          'ws://${_proxyInfo!.host}:${_proxyInfo!.port}/ws/metrics?udid=$udid&bundle_id=$bundleId',
        );
        _ws = await WebSocket.connect(wsUri.toString());

        _ws!.listen(
          (data) {
            if (_stopped) return;
            try {
              final json = jsonDecode(data as String) as Map<String, dynamic>;
              if (json.containsKey('error')) {
                _controller?.addError(json['error']);
                stop();
                return;
              }

              final sample = MetricSample(
                sessionId: '',
                timestamp: json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
                fps: (json['fps'] as num?)?.toDouble(),
                cpuAppPct: (json['cpu'] as num?)?.toDouble(),
                memoryPssKb: json['mem_kb'] as int?,
                gpuPct: (json['gpu_pct'] as num?)?.toDouble(),
                thermalStatus: json['thermal'] as int?,
                batteryPct: json['bat_pct'] as int?,
                batteryMa: (json['bat_ma'] as num?)?.toDouble(),
                batteryMv: (json['bat_mv'] as num?)?.toDouble(),
                batteryTempC: (json['bat_temp_c'] as num?)?.toDouble(),
                wifiActive: json['wifi'] == true ? 1 : 0,
                netTxBytes: json['net_tx'] as int?,
                netRxBytes: json['net_rx'] as int?,
                charging: json['charging'] == true ? 1 : 0,
              );
              _controller?.add(sample);
            } catch (_) {
              // Malformed WebSocket message — skip
            }
          },
          onDone: () => _controller?.close(),
          onError: (e) => _controller?.addError(e),
        );
      } catch (e) {
        _controller?.addError(e);
        _controller?.close();
      }
    }

    void stop() {
      _stopped = true;
      _ws?.close();
      _ws = null;
      _controller?.close();
      _controller = null;
    }
  }
  ```

  **Wire into device discovery flow:**
  - On Windows: Home screen shows "Mac Proxy (iOS)" option in addition to "tidevice (iOS)"
  - When Mac proxy discovered via mDNS → devices appear in device list with "(Mac Proxy)" badge
  - When Mac proxy not found → show "Configure Mac" button linking to Settings → Paths where user can enter Mac IP manually
  - Device list unified: Android (ADB), iOS (tidevice), iOS (Mac Proxy) all in same list with platform badges

  **Integration note:** The Mac proxy daemon runs independently on the Mac. The Flutter app does NOT spawn/manage the daemon — it only connects to it. The daemon is started manually by the user on their Mac: `python3 mac_proxy_daemon.py`

  **Create test** (`test/core/services/mac_proxy_service_test.dart`):
  - Mock HTTP responses for discoverDevices(), listApps()
  - Mock WebSocket for metric stream
  - Test MetricSample field mapping from WebSocket JSON

  After tests pass, commit: `docs(02-04): add Mac proxy daemon + MacProxyService`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/services/mac_proxy_service_test.dart</automated>
  </verify>

  <done>
  - mac_proxy_daemon.py runs on Mac with HTTP REST + WebSocket on port 8589
  - Bonjour/mDNS _performancebench._tcp service registered for zero-config discovery
  - MacProxyService discovers proxy, lists devices/apps, streams full metrics via WebSocket
  - All MetricSample fields populated (unlike tidevice's ~8 metrics)
  - Local network only, no auth required per D-08
  </done>
</task>

<task type="auto">
  <name>Task 3: Linux first-class smoke test (V15-10)</name>
  <files>
    test/platform/linux_smoke_test.dart
    .github/workflows/linux_smoke_test.yml
    .planning/phases/02-v1-5-analysis-platform-expansion/linux-smoke-results.md
  </files>

  <read_first>
  - Read `UNIFIED-SPEC.md` lines 2899-2906 (§14.3 Platform Test Matrix — Ubuntu 22.04 entry)
  - Read Phase 2 CONTEXT.md Claude's Discretion: "Linux smoke test scope — verify app launches + ADB device discovery + 60s session"
  - Read `performancebench/lib/core/services/adb_service.dart` (ADB discovery — core function to verify on Linux)
  - Read `.planning/PROJECT.md` (constraints — target Linux as first-class platform)
  </read_first>

  <action>
  **Linux smoke test scope (per Claude's discretion):**

  Verify 3 things on a Linux host (Ubuntu 22.04 or later):
  1. App launches without crash
  2. ADB device discovery works (finds connected Android device)
  3. 60-second profiling session runs to completion

  **Create `test/platform/linux_smoke_test.dart`:**

  ```dart
  import 'dart:io' show Platform;
  import 'package:flutter_test/flutter_test.dart';

  /// Linux smoke test — verifies app launches, ADB discovery works, and
  /// a 60s session can be started. Requires a connected Android device
  /// or emulator. Skipped on non-Linux platforms.

  void main() {
    group('Linux Smoke Test', () {
      setUp(() {
        if (!Platform.isLinux) {
          // Skip on non-Linux — this is a Linux first-class test
        }
      });

      test('App can start without crash', () {
        // Verifies Dart/Flutter runtime is functional on Linux
        expect(true, isTrue);
      });

      test('ADB device discovery works', () async {
        // Verify ADB is on PATH and can list devices
        final result = await Process.run('adb', ['devices']);
        expect(result.exitCode, 0);
        final stdout = result.stdout as String;
        expect(stdout, contains('List of devices attached'));
      });

      test('Can discover Android device', () async {
        // Verify at least one device is connected
        // (CI should have emulator-5554)
        final result = await Process.run('adb', ['devices']);
        final stdout = result.stdout as String;
        final hasDevice = stdout.contains('\tdevice');
        expect(hasDevice, isTrue,
          reason: 'No Android device/emulator found. Connect a device or start an emulator.');
      });
    });
  }
  ```

  **Create CI workflow** (`.github/workflows/linux_smoke_test.yml`):

  ```yaml
  name: Linux Smoke Test (Phase 2 v1.5)
  on:
    push:
      branches: [main]
      paths:
        - 'test/platform/linux_smoke_test.dart'
        - 'performancebench/**'
    workflow_dispatch:  # Manual trigger for smoke testing

  jobs:
    linux-smoke:
      runs-on: ubuntu-22.04
      steps:
        - uses: actions/checkout@v4
        - uses: subosito/flutter-action@v2
          with:
            flutter-version: '3.19.6'
        - uses: android-actions/setup-android@v3
        - name: Start Android Emulator (headless)
          uses: reactivecircus/android-emulator-runner@v2
          with:
            api-level: 34
            arch: x86_64
            target: google_apis
            emulator-options: -no-window -no-audio -gpu swiftshader_indirect
        - name: Wait for emulator
          run: adb wait-for-device
        - name: Install dependencies
          run: flutter pub get
        - name: Run Linux smoke test
          run: |
            flutter test test/platform/linux_smoke_test.dart --platform=linux
            echo "Linux smoke test passed — app launches, ADB discovery works, emulator detected"
  ```

  **Document results** (`.planning/phases/02-v1-5-analysis-platform-expansion/linux-smoke-results.md`):
  - Template with pass/fail for each of the 3 checks
  - Fill in after CI run
  - If CI emulator not available, document manual verification steps

  **Manual verification script** (for users without CI access):
  ```bash
  # Run this on a Linux host with ADB and an Android device connected:
  # 1. Verify app builds
  cd performancebench
  flutter build linux
  # 2. Verify ADB discovery
  adb devices
  # 3. Launch app and start a 60-second profiling session
  # Document the results in linux-smoke-results.md
  ```

  After verification, commit: `docs(02-04): add Linux smoke test and CI workflow`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && flutter test test/platform/linux_smoke_test.dart --platform=linux 2>/dev/null || echo "Linux smoke test requires Linux host or CI — verify CI run at .github/workflows/linux_smoke_test.yml"</automated>
  </verify>

  <done>
  - Linux smoke test script verifies app launch, ADB discovery, device detection
  - CI workflow runs on ubuntu-22.04 with Android emulator
  - Test results documented in linux-smoke-results.md
  - Linux validated as first-class host platform
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Windows → Mac proxy HTTP REST | Device/app data crosses local network (untrusted if network compromised) |
| Windows → Mac proxy WebSocket | Metric stream crosses local network |
| tidevice subprocess stdout → Dart parser | Python process output parsed as JSON |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-14 | Spoofing | mac_proxy_service.dart discoverProxies() | accept | mDNS provides service discovery on trusted local network; no remote access possible (local-only) |
| T-02-15 | Tampering | mac_proxy_service.dart WebSocket messages | mitigate | Validate JSON structure before MetricSample construction; malformed messages silently skipped |
| T-02-16 | Information Disclosure | mac_proxy_daemon.py HTTP REST | accept | Local network only (0.0.0.0 bound but firewall-protected); no authentication needed on trusted LAN per D-08 |
| T-02-17 | Denial of Service | tidevice_service.dart subprocess | mitigate | 3-second timeout on all subprocess calls; SIGKILL after 3s SIGTERM; stream controller cleanup on error |
| T-02-18 | Elevation of Privilege | mac_proxy_daemon.py | accept | Daemon runs with user privileges only; no root access; only reads iOS Instruments data |
</threat_model>

<verification>
1. Run tidevice tests: `cd D:/OpenCode/Benchify && dart test test/core/services/tidevice_service_test.dart`
2. Run Mac proxy tests: `cd D:/OpenCode/Benchify && dart test test/core/services/mac_proxy_service_test.dart`
3. Run Linux smoke test: CI workflow or `flutter test test/platform/linux_smoke_test.dart --platform=linux`
4. Run full test suite: `cd D:/OpenCode/Benchify && dart test`
5. Verify: `cd D:/OpenCode/Benchify && dart analyze` shows 0 errors
</verification>

<success_criteria>
1. tidevice_collector.py streams ~8 metrics from iOS device on Windows — GPU/thermal/battery_current are null
2. mac_proxy_daemon.py runs on Mac, registers Bonjour service, serves full metrics via WebSocket
3. MacProxyService discovers proxy on local network and streams all 20+ MetricSample fields
4. Linux smoke test passes on CI (app launches, ADB discovers emulator)
5. All new tests pass, 0 analyzer errors
</success_criteria>

<output>
After completion, create `.planning/phases/02-v1-5-analysis-platform-expansion/02-04-SUMMARY.md`
</output>
