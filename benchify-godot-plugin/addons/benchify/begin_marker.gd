# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Benchify
#
# begin_marker.gd — Scoped marker using Godot `with` pattern.
# Per D-02: Usage: "with BeginMarker.new('boss_fight'):" — cleanup on scope exit.
# Extends RefCounted for automatic cleanup via NOTIFICATION_PREDELETE.

class_name BeginMarker
extends RefCounted

var _name: String
var _ended: bool = false


## Create a scoped marker and immediately start it.
## Usage: with BeginMarker.new("boss_fight"):
##            do_boss_spawn()
func _init(name: String) -> void:
	_name = name if not name.is_empty() else "unnamed_marker"
	Benchify.begin_marker(_name)


## Cleanup on scope exit (NOTIFICATION_PREDELETE triggered by `with` pattern).
## Calls Benchify.end_marker() to complete the scoped marker.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _ended:
		_ended = true
		Benchify.end_marker()


## Manually end the marker early (before scope exit).
func end() -> void:
	if not _ended:
		_ended = true
		Benchify.end_marker()
