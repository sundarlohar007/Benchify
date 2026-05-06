# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Benchify
#
# editor_dock.gd — Godot EditorPlugin for Benchify stats dock.
# Per D-03: Read-only dock at bottom panel showing FPS, draw calls, memory.
# @tool script — runs in editor context.

@tool
extends EditorPlugin

var _dock: Control
var _fps_label: Label
var _draw_calls_label: Label
var _objects_label: Label
var _material_label: Label
var _verts_label: Label
var _refresh_timer: Timer


func _enter_tree() -> void:
	# Build dock UI
	_dock = _create_dock_ui()

	# Register as bottom panel dock
	add_control_to_bottom_panel(_dock, "Benchify")

	# Auto-refresh timer (2Hz during editor play)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.timeout.connect(_on_refresh)
	_dock.add_child(_refresh_timer)
	_refresh_timer.start()


func _exit_tree() -> void:
	if _refresh_timer:
		_refresh_timer.stop()
		_refresh_timer.queue_free()

	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()


func _create_dock_ui() -> Control:
	var container = VBoxContainer.new()

	# Title
	var title = Label.new()
	title.text = "Benchify Profiler"
	title.add_theme_font_size_override("font_size", 16)
	container.add_child(title)

	var sep = HSeparator.new()
	container.add_child(sep)

	# FPS
	_fps_label = Label.new()
	_fps_label.text = "FPS: --"
	_fps_label.add_theme_font_size_override("font_size", 18)
	container.add_child(_fps_label)

	# Draw Calls
	_draw_calls_label = Label.new()
	_draw_calls_label.text = "Draw Calls: --"
	container.add_child(_draw_calls_label)

	# Objects Drawn
	_objects_label = Label.new()
	_objects_label.text = "Objects: --"
	container.add_child(_objects_label)

	# Material Changes
	_material_label = Label.new()
	_material_label.text = "Material Changes: --"
	container.add_child(_material_label)

	# Vertices
	_verts_label = Label.new()
	_verts_label.text = "Vertices: --"
	container.add_child(_verts_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	container.add_child(spacer)

	# Open Desktop App button
	var button = Button.new()
	button.text = "Open PerformanceBench Desktop"
	button.pressed.connect(_on_open_desktop_pressed)
	container.add_child(button)

	return container


func _on_refresh() -> void:
	# Update labels if Benchify autoload is available
	_update_label(_fps_label, "FPS", Benchify.get_fps() if Benchify.has_method("get_fps") else -1, "%.1f")

	var stats = Benchify.get_frame_stats() if Benchify.has_method("get_frame_stats") else {}

	_update_label_int(_draw_calls_label, "Draw Calls", stats.get("draw_calls", 0))
	_update_label_int(_objects_label, "Objects", stats.get("objects_drawn", 0))
	_update_label_int(_material_label, "Material Changes", stats.get("material_changes", 0))
	_update_label_int(_verts_label, "Vertices", stats.get("verts_drawn", 0))


func _update_label(label: Label, prefix: String, value: float, format: String) -> void:
	if value >= 0:
		label.text = "%s: %s" % [prefix, format % value]
	else:
		label.text = "%s: --" % prefix


func _update_label_int(label: Label, prefix: String, value: int) -> void:
	if value > 0:
		label.text = "%s: %d" % [prefix, value]
	else:
		label.text = "%s: --" % prefix


func _on_open_desktop_pressed() -> void:
	OS.shell_open("https://github.com/sundarlohar007/Benchify")
