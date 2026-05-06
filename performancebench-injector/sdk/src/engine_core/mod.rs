/// Engine core — shared Rust library for game engine profiling plugins.
///
/// This module provides the shared logic reused by all three engine wrappers:
/// - Unity: C# P/Invoke wrapper
/// - Unreal: C++ FFI wrapper
/// - Godot: GDScript Foreign Interface wrapper
///
/// Per D-01: Shared Rust core library with auto-marker logic and metric collection.
///
/// MIT License — Copyright (c) 2026 Benchify

pub mod marker;
pub mod auto_marker;
pub mod metrics;
