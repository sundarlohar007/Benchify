# Benchify

Free, open-source mobile + desktop performance profiler — **GameBench alternative at $0**.  
100% local data. Zero telemetry. MIT license.

[![CI](https://github.com/sundarlohar007/Benchify/actions/workflows/desktop-ci.yml/badge.svg)](https://github.com/sundarlohar007/Benchify/actions/workflows/desktop-ci.yml)
[![Web](https://github.com/sundarlohar007/Benchify/actions/workflows/web-dashboard-ci.yml/badge.svg)](https://github.com/sundarlohar007/Benchify/actions/workflows/web-dashboard-ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What is Benchify?

Benchify (internally "PerformanceBench") is a complete performance profiling platform for mobile and desktop applications. Plug in your device via USB, pick an app, and start capturing FPS, CPU, GPU, Memory, Battery, Network, and Thermal metrics in real-time — all without touching the target app's source code.

## Quick Start

### Desktop Profiler (plug-in-and-go)

1. Download the installer for your platform from [Releases](https://github.com/sundarlohar007/Benchify/releases)
2. Install and launch PerformanceBench
3. Connect your Android device via USB (enable USB Debugging first)
4. Select the target app → **Start Profiling**

### SDK Injection (for deeper metrics)

```bash
cd performancebench-injector
pip install -r requirements.txt
python injector_cli.py inject --apk your_app.apk --method smali --output patched.apk
adb install patched.apk
```

Then launch the patched app — PerformanceBench desktop will automatically detect the embedded SDK and stream enriched metrics.

## Project Structure

```
Benchify/
├── performancebench/              # Desktop profiler (Flutter, Windows/macOS/Linux)
├── performancebench-mobile/       # Mobile companion app (Flutter, Android/iOS)
├── performancebench-injector/     # APK/IPA injection toolchain (Python + Rust SDK)
│   ├── sdk/                       #   Rust SDK (.so injected into target apps)
│   └── pcprobe/                   #   PC-side metrics probe (Rust binary)
├── performancebench-server/       # Backend API server (Rust/Axum + PostgreSQL)
├── performancebench-web/          # Web analytics dashboard (React + TypeScript)
├── benchify-unity-plugin/         # Unity SDK plugin
├── benchify-unreal-plugin/        # Unreal Engine SDK plugin
├── benchify-godot-plugin/         # Godot SDK plugin
└── .github/workflows/             # CI/CD + release automation
```

## Platform Support

| Platform | Android Profiling | iOS Profiling | Desktop App | Mobile Companion |
|----------|:-----------------:|:-------------:|:-----------:|:----------------:|
| Windows  | ✅ | — | ✅ | — |
| macOS    | ✅ | ✅ | ✅ | — |
| Linux    | ✅ | — | ✅ | — |
| Android  | — | — | — | ✅ |
| iOS      | — | — | — | ✅ |

## Metrics

| Metric | Android | iOS | PC (via pcprobe) |
|--------|:-------:|:---:|:----------------:|
| FPS    | ✅ | ✅ | ✅ |
| CPU    | ✅ | ✅ | ✅ |
| GPU    | ✅ | ✅ | ✅ |
| Memory | ✅ | ✅ | ✅ |
| Battery| ✅ | ✅ | — |
| Network| ✅ | ✅ | ✅ |
| Thermal| ✅ | ✅ | — |
| Jank   | ✅ | ✅ | — |

## Release Artifacts

Every tagged release (`git tag v0.1.0 && git push --tags`) automatically builds:

| Artifact | Format |
|----------|--------|
| Windows installer | `.exe` (NSIS) |
| macOS DMG | `.dmg` (drag-to-install) |
| macOS PKG | `.pkg` (wizard installer) |
| Linux AppImage | `.AppImage` (portable) |
| Android companion | `.apk` (debug-signed) |
| iOS companion | `.ipa` (unsigned, sideload via AltStore) |
| Unity SDK plugin | `.zip` |
| Unreal SDK plugin | `.zip` |
| Godot SDK plugin | `.zip` |
| Injector CLI | `.zip` (Python tool) |

## Build from Source

### Desktop App
```bash
cd performancebench
flutter pub get
flutter run -d windows   # or macos, linux
```

### Web Dashboard
```bash
cd performancebench-web
pnpm install
pnpm dev
```

### Injector + Rust SDK
```bash
cd performancebench-injector
pip install -r requirements.txt
cd sdk && cargo build --release
```

### Server
```bash
cd performancebench-server
cargo run
```

## Game Engine SDKs

Drop-in performance profiling for game engines:

- **Unity** — `benchify-unity-plugin/` → Import via Package Manager
- **Unreal** — `benchify-unreal-plugin/` → Copy to Plugins/
- **Godot** — `benchify-godot-plugin/` → Enable in Project Settings

Each SDK auto-reports FPS, frame times, memory, and CPU via the injected Rust `.so` library.

## Documentation

- [Full Specification](UNIFIED-SPEC.md) — 300KB+ behavioral spec with SQL schemas, metric formulas, and API contracts
- [Implementation Plan](implementation_plan.md) — Sprint breakdown and phase summary

## Privacy

**PerformanceBench NEVER transmits any data.** All profiling data stays on your machine. This is verified by an automated CI packet-capture test that monitors network traffic during a 30-minute profiling session on every commit.

## License

MIT — see [LICENSE](LICENSE)
