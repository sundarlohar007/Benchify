# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Benchify
#
# benchify_autoload.gd — Godot Autoload singleton for Benchify Profiling.
# Per D-01: Auto-marker on SceneTree.scene_changed signal.
# Per D-03: RenderingServer draw call queries during editor play.
# Class name: Benchify — accessible globally as Benchify.begin_marker("name").

extends Node

# ── Signals ──────────────────────────────────────────
signal marker_started(name: String)
signal marker_ended(name: String)

# ── State ────────────────────────────────────────────
var _frame_count: int = 0
var _frame_accum: float = 0.0
var _current_fps: float = 0.0
var _latest_draw_calls: int = 0
var _latest_objects_drawn: int = 0
var _latest_material_changes: int = 0
var _latest_shader_changes: int = 0
var _latest_surface_changes: int = 0
var _latest_verts_drawn: int = 0
var _active_marker_name: String = ""

# ── Lifecycle ────────────────────────────────────────

func _ready() -> void:
	# Connect scene change signal for auto-markers (per D-01)
	if get_tree():
		get_tree().scene_changed.connect(_on_scene_changed)

	# Emit app start marker
	_on_app_start()


func _process(delta: float) -> void:
	_frame_count += 1
	_frame_accum += delta

	# Collect per-frame RenderingServer stats
	_collect_frame_stats()

	# Aggregate at 1Hz
	if _frame_accum >= 1.0:
		_current_fps = float(_frame_count) / _frame_accum
		_push_frame_stats_to_native()

		_frame_accum = 0.0
		_frame_count = 0


# ── Public API ───────────────────────────────────────

## Begin a named scoped performance marker.
## Usage: Benchify.begin_marker("boss_fight")
func begin_marker(name: String) -> void:
	if name.is_empty():
		return

	_active_marker_name = name
	marker_started.emit(name)
	_begin_native_marker(name)


## End the current scoped performance marker.
func end_marker() -> void:
	if _active_marker_name.is_empty():
		return

	var name = _active_marker_name
	_active_marker_name = ""
	marker_ended.emit(name)
	_end_native_marker()


## Get the current FPS (rolling 1-second average).
func get_fps() -> float:
	return _current_fps


## Get the latest draw call count.
func get_draw_calls() -> int:
	return _latest_draw_calls


## Get the latest frame stats as a Dictionary.
func get_frame_stats() -> Dictionary:
	return {
		"engine": "godot",
		"fps": _current_fps,
		"draw_calls": _latest_draw_calls,
		"objects_drawn": _latest_objects_drawn,
		"material_changes": _latest_material_changes,
		"shader_changes": _latest_shader_changes,
		"surface_changes": _latest_surface_changes,
		"verts_drawn": _latest_verts_drawn
	}


# ── Auto-Markers ─────────────────────────────────────

func _on_scene_changed(scene_root: Node) -> void:
	var scene_name = "Unknown"
	if scene_root and scene_root.scene_file_path:
		scene_name = scene_root.scene_file_path.get_file()

	# Create auto-marker for scene transition
	begin_marker("Scene:" + scene_name)
	end_marker()  # Scene load markers are point events


func _on_app_start() -> void:
	begin_marker("App Launch")
	end_marker()


# ── Frame Stats Collection ───────────────────────────

func _collect_frame_stats() -> void:
	var rs = RenderingServer

	# Query RenderingServer info enums (Godot 4.2+)
	# RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME = 0
	# RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME = 1
	# RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME = 2
	# RENDERING_INFO_TOTAL_MATERIAL_CHANGES_IN_FRAME = 9
	# RENDERING_INFO_TOTAL_SHADER_CHANGES_IN_FRAME = 10
	# RENDERING_INFO_TOTAL_SURFACE_CHANGES_IN_FRAME = 11

	_latest_objects_drawn = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	_latest_verts_drawn = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	_latest_draw_calls = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_latest_material_changes = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_MATERIAL_CHANGES_IN_FRAME)
	_latest_shader_changes = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_SHADER_CHANGES_IN_FRAME)
	_latest_surface_changes = rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_SURFACE_CHANGES_IN_FRAME)


func _push_frame_stats_to_native() -> void:
	# Build JSON matching engine_core::metrics::GodotFrameStats format
	var stats = get_frame_stats()
	var json_str = JSON.stringify(stats)

	# Push to native GDExtension if loaded
	# Calls into metrics_provider.gdextension -> Rust engine_core
	if MetricsProvider and MetricsProvider.has_method("collect_frame_stats"):
		MetricsProvider.collect_frame_stats(json_str)


func _begin_native_marker(name: String) -> void:
	# Call Rust engine_core via GDExtension
	if MetricsProvider and MetricsProvider.has_method("begin_marker"):
		MetricsProvider.begin_marker(name)


func _end_native_marker() -> void:
	if MetricsProvider and MetricsProvider.has_method("end_marker"):
		MetricsProvider.end_marker()
