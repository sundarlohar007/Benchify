# PerformanceBench

Free, open-source mobile performance profiler — GameBench alternative at $0. Local-only data, MIT license.

[![CI](https://github.com/sundarlohar007/Benchify/actions/workflows/ci.yml/badge.svg)](https://github.com/sundarlohar007/Benchify/actions/workflows/ci.yml)

## Quick Start

1. Download from [GitHub Releases](https://github.com/sundarlohar007/Benchify/releases)
2. Install ADB: `brew install android-platform-tools` (macOS) or `choco install adb` (Windows)
3. Enable USB Debugging on Android (Settings > Developer Options)
4. Launch PerformanceBench and connect device
5. Select app → **Start Profiling**

## Build from Source

```bash
git clone https://github.com/sundarlohar007/Benchify
cd Benchify/performancebench
flutter pub get
flutter run -d windows  # or macos, linux
```

## Features

- **20+ real-time metrics**: FPS, CPU, Memory, Battery, Network, Thermal, GPU at 1Hz
- **Android + iOS**: Android via ADB, iOS via pyidevice (macOS only)
- **VS Code-inspired dark theme**: 4 variants (Dark/Light/High Contrast/System)
- **Session history**: Filter, sort, search past sessions
- **Session comparison**: Side-by-side delta with regression detection
- **JSON/CSV export**: Full session data export
- **100% local**: No data ever leaves your machine

## Platform Support

| Platform | Android Profiling | iOS Profiling | App Runs On |
|----------|:--:|:--:|:--:|
| Windows  | ✓ | ✗ | ✓ |
| macOS    | ✓ | ✓ | ✓ |
| Linux    | ✓ | ✗ | ✓ |

## Metric Parity

| Metric   | Android | iOS |
|----------|:--:|:--:|
| FPS      | ✓ | ✓ |
| CPU      | ✓ | ✓ |
| Memory   | ✓ | ✓ |
| Battery  | ✓ | ✓ |
| Network  | ✓ | ✓ |
| Thermal  | ✓ | ✓ |
| GPU      | ✓ | ✓ |
| Jank     | ✓ | ✓ |

## Documentation

- [Full Specification](../UNIFIED-SPEC.md)
- [Implementation Plan](../implementation_plan.md)
- [CHANGELOG](CHANGELOG.md)

## License

MIT — see [LICENSE](LICENSE)

## Privacy

PerformanceBench NEVER transmits data. All profiling data stays on your machine. Verified by automated CI packet-capture test on every commit.
