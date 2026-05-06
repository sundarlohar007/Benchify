# Benchify Unreal Engine Plugin

Free, open-source performance profiler for Unreal Engine games. Auto-markers, RHI/GPU stats, FPS overlay during PIE. Zero cloud dependency — all data stays local.

## Installation

Clone the plugin into your project's Plugins directory:

```bash
# From your Unreal project root:
mkdir -p Plugins
git clone https://github.com/sundarlohar007/Benchify.git temp-benchify
cp -r temp-benchify/benchify-unreal-plugin Plugins/Benchify
rm -rf temp-benchify
```

Or download the zip and extract into `YourProject/Plugins/Benchify/`.

After installation:
1. Regenerate project files (right-click .uproject > Generate Visual Studio project files)
2. Build your project
3. Enable the plugin in Edit > Plugins > Performance > Benchify Profiler

## Quick Start

### Blueprint

Add a `BeginMarker` node anywhere in your Blueprint graph:

1. Search for "Begin Marker" in Blueprint action menu
2. Enter a marker name (e.g., "boss_fight")
3. Call `End Marker` when the scope completes

### C++

```cpp
#include "BenchifyBPLibrary.h"

void AMyActor::BeginPlay()
{
    Super::BeginPlay();
    UBenchifyBPLibrary::BeginMarker(TEXT("level_start"));
}

void AMyActor::EndPlay(const EEndPlayReason::Type Reason)
{
    UBenchifyBPLibrary::EndMarker();
    Super::EndPlay(Reason);
}
```

## Editor Window

**Window > Benchify Profiler** opens a dockable tab showing:
- FPS (green/yellow/red color-coded badge)
- RHI frame time (ms)
- GPU frame time (ms)
- Draw primitive calls
- Stat Unit values

Stats auto-refresh during Play In Editor (PIE). Read-only — full profiling control via PerformanceBench desktop app.

## Auto-Markers

The plugin automatically creates markers on:
- **Map loads** — Marker: "Scene:MapName"
- **App start** — Marker: "App Launch"

Markers appear in the PerformanceBench desktop app session timeline.

## Architecture

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Engine Subsystem | `UBenchifySubsystem` | Auto-markers + frame stat collection |
| Blueprint Library | `UBenchifyBPLibrary` | BeginMarker/EndMarker Blueprint nodes |
| Native Bridge | `FBenchifyNativeBridge` | FFI to Rust `benchify_engine` shared lib |
| Editor Widget | `SBenchifyEditorWidget` | Slate editor stats dashboard |

## Platform Support

| Platform | Native Library | Path |
|----------|---------------|------|
| Windows  | `benchify_engine.dll` | `Plugins/Benchify/Binaries/Win64/` |
| macOS    | `libbenchify_engine.dylib` | `Plugins/Benchify/Binaries/Mac/` |
| Linux    | `libbenchify_engine.so` | `Plugins/Benchify/Binaries/Linux/` |

## License

MIT — Copyright (c) 2026 Benchify

## Links

- [PerformanceBench Desktop App](https://github.com/sundarlohar007/Benchify)
- [Benchify Unity Plugin](https://github.com/sundarlohar007/Benchify/tree/main/benchify-unity-plugin)
- [Benchify Godot Plugin](https://github.com/sundarlohar007/Benchify/tree/main/benchify-godot-plugin)
