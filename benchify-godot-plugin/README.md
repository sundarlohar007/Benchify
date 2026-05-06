# Benchify Godot Plugin

Free, open-source performance profiler for Godot Engine games. Auto-markers, RenderingServer draw call queries, FPS overlay during editor play. Zero cloud dependency — all data stays local.

## Installation

1. Copy `addons/benchify/` into your Godot project's `addons/` directory
2. Open **Project > Project Settings > Plugins**
3. Enable **Benchify Profiler**

Or clone from GitHub:

```bash
# From your Godot project root:
git clone https://github.com/sundarlohar007/Benchify.git temp-benchify
cp -r temp-benchify/benchify-godot-plugin/addons/benchify addons/
rm -rf temp-benchify
```

## Quick Start

Use the `with` pattern for scoped markers anywhere in GDScript:

```gdscript
# Profile a specific operation
with BeginMarker.new("boss_fight"):
    spawn_boss()
    start_combat_music()
# Marker auto-ends here

# Manual marker (without with):
Benchify.begin_marker("level_load")
# ... your code ...
Benchify.end_marker()
```

## Autoload API

The `Benchify` singleton is available globally:

```gdscript
# Get current FPS
var fps = Benchify.get_fps()

# Get full frame stats dictionary
var stats = Benchify.get_frame_stats()
print(stats.draw_calls)
print(stats.objects_drawn)
```

## Editor Dock

**Bottom Panel > Benchify** shows live stats during editor play:
- FPS (color-coded: green >= 55, yellow >= 30, red < 30)
- Draw calls (RenderingServer queries)
- Objects drawn, vertices, material changes per frame

Stats auto-refresh at 2Hz during editor play. Read-only — profiling control via PerformanceBench desktop app.

## Auto-Markers

The plugin automatically creates markers on:
- **Scene changes** — Marker: "Scene:scene_name.tscn"
- **App start** — Marker: "App Launch"

Markers appear in the PerformanceBench desktop app session timeline.

## Metrics Collected

| Stat | Source |
|------|--------|
| Draw Calls | `RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME` |
| Objects Drawn | `RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME` |
| Primitives | `RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME` |
| Material Changes | `RenderingServer.RENDERING_INFO_TOTAL_MATERIAL_CHANGES_IN_FRAME` |
| Shader Changes | `RenderingServer.RENDERING_INFO_TOTAL_SHADER_CHANGES_IN_FRAME` |
| Surface Changes | `RenderingServer.RENDERING_INFO_TOTAL_SURFACE_CHANGES_IN_FRAME` |

## Architecture

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Autoload | `benchify_autoload.gd` | Scene auto-markers + metric collection |
| Scoped Marker | `begin_marker.gd` | `with` pattern via RefCounted |
| Editor Dock | `editor_dock.gd` | Read-only stats dock |
| GDExtension | `metrics_provider.gdextension` | FFI to Rust `benchify_engine` |

## Requirements

- Godot 4.2 or later

## License

MIT — Copyright (c) 2026 Benchify

## Links

- [PerformanceBench Desktop App](https://github.com/sundarlohar007/Benchify)
- [Benchify Unity Plugin](https://github.com/sundarlohar007/Benchify/tree/main/benchify-unity-plugin)
- [Benchify Unreal Plugin](https://github.com/sundarlohar007/Benchify/tree/main/benchify-unreal-plugin)
