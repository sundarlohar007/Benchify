# Benchify Unity Plugin

Free, open-source performance profiler for Unity games. Auto-markers, draw calls, memory, FPS overlay during Play mode. Zero cloud dependency — all data stays local.

## Installation

### Via UPM (Recommended)

Add the following git URL in Unity Package Manager:

```
https://github.com/sundarlohar007/Benchify.git?path=/benchify-unity-plugin
```

1. Open Unity Editor (2022.3 LTS or later)
2. Window > Package Manager
3. Click "+" > "Add package from git URL..."
4. Paste the URL above
5. Click "Add"

### Manual Install

Clone the repo and copy `benchify-unity-plugin/` into your project's `Packages/` folder:

```bash
git clone https://github.com/sundarlohar007/Benchify.git
cp -r Benchify/benchify-unity-plugin YourProject/Packages/dev.benchify.unity-plugin
```

## Quick Start

Add a scoped marker around any code block:

```csharp
using Benchify;

// Profile a specific operation
using (new BeginMarker("boss_fight"))
{
    SpawnBoss();
    StartCombatMusic();
}
```

The marker appears in the PerformanceBench desktop app session timeline.

## Editor Window

**Window > Benchify Profiler** opens a read-only stats dashboard showing:
- FPS (green/yellow/red color-coded)
- Draw calls, batches, SetPass calls
- Mono heap size (MB, with 1GB scale bar)
- GC allocation per frame (KB, red warning if > 1MB)

Enter Play mode to see live stats. The editor window auto-refreshes.

## Settings

**Edit > Project Settings > Benchify** to configure:
- TCP port (default 8080) for desktop app connection
- Auto-markers toggle (automatic markers on scene load)
- Stats refresh interval (0.1 - 5.0 seconds)

## Production Builds

All Benchify code is guarded behind `#if PERFORMANCE_BENCH`. In release builds without this define, the plugin has zero code retained — no IL2CPP stripping needed.

Define `PERFORMANCE_BENCH` in **Player Settings > Scripting Define Symbols** when profiling.

## Architecture

| Layer | Technology | Purpose |
|-------|-----------|---------|
| C# MonoBehaviour | `BenchifyPlugin.cs` | Frame sampling + stats aggregation |
| C# Scoped Marker | `BeginMarker.cs` | `IDisposable`-based BeginMarker/EndMarker |
| C# P/Invoke | `NativeBindings.cs` | Bridge to Rust `benchify_engine` native lib |
| Rust Core | `engine_core/` | Shared marker state machine + metric collection |

## License

MIT — Copyright (c) 2026 Benchify

## Links

- [PerformanceBench Desktop App](https://github.com/sundarlohar007/Benchify)
- [Full UNIFIED-SPEC.md](https://github.com/sundarlohar007/Benchify/blob/main/UNIFIED-SPEC.md)
