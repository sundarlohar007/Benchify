/// Engine-specific metric collectors for game engine profiling.
///
/// Each game engine exposes different performance stats through its own API.
/// These structs collect engine-native metrics that the Rust core doesn't
/// have direct access to — the engine wrappers populate these and push them
/// via JSON to the TCP transport.
///
/// Per D-01: Shared Rust core — metric collector bridge reused by all three engine wrappers.
///
/// MIT License — Copyright (c) 2026 Benchify

/// Unity-specific per-frame rendering and memory statistics.
/// Populated by Unity C# plugin via `UnityStats` and `Profiler` APIs.
#[derive(Debug, Clone, Default)]
pub struct UnityFrameStats {
    /// Number of draw calls issued this frame.
    pub draw_calls: i32,
    /// Number of batches (static + dynamic) this frame.
    pub batches: i32,
    /// Number of SetPass calls (shader/material switches) this frame.
    pub setpass_calls: i32,
    /// Mono managed heap size in kilobytes.
    pub mono_heap_kb: i64,
    /// GC allocation delta for this frame in kilobytes.
    pub gc_alloc_kb: i64,
    /// Number of triangles rendered this frame.
    pub triangles: i32,
    /// Number of vertices processed this frame.
    pub vertices: i32,
}

impl UnityFrameStats {
    /// Serialize to JSON for TCP streaming to desktop app.
    pub fn to_json(&self) -> String {
        format!(
            r#"{{"engine":"unity","draw_calls":{},"batches":{},"setpass_calls":{},"mono_heap_kb":{},"gc_alloc_kb":{},"triangles":{},"vertices":{}}}"#,
            self.draw_calls,
            self.batches,
            self.setpass_calls,
            self.mono_heap_kb,
            self.gc_alloc_kb,
            self.triangles,
            self.vertices,
        )
    }

    /// Push these stats to the transport queue for the desktop app.
    pub fn queue_to_transport(&self) {
        let json = self.to_json();
        crate::transport::push_event_json(&json);
    }
}

/// Unreal Engine-specific per-frame stats.
/// Populated by Unreal C++ plugin via `FApp`, `GDynamicRHI`, etc.
#[derive(Debug, Clone, Default)]
pub struct UnrealFrameStats {
    /// RHI (Render Hardware Interface) frame time in milliseconds.
    pub rhi_frame_time_ms: f64,
    /// Number of draw primitive calls this frame.
    pub draw_primitive_calls: i32,
    /// GPU frame time in milliseconds from RHI.
    pub gpu_frame_time_ms: f64,
    /// Full Stat Unit JSON from Unreal Engine (`stat unit` command output).
    pub stat_unit_json: String,
}

impl UnrealFrameStats {
    /// Serialize to JSON for TCP streaming.
    pub fn to_json(&self) -> String {
        format!(
            r#"{{"engine":"unreal","rhi_frame_time_ms":{},"draw_primitive_calls":{},"gpu_frame_time_ms":{},"stat_unit_json":{}}}"#,
            self.rhi_frame_time_ms,
            self.draw_primitive_calls,
            self.gpu_frame_time_ms,
            self.stat_unit_json,
        )
    }

    /// Push these stats to the transport queue.
    pub fn queue_to_transport(&self) {
        let json = self.to_json();
        crate::transport::push_event_json(&json);
    }
}

/// Godot Engine-specific per-frame stats.
/// Populated by Godot GDScript plugin via `RenderingServer` API.
#[derive(Debug, Clone, Default)]
pub struct GodotFrameStats {
    /// Number of draw calls this frame.
    pub draw_calls: i32,
    /// Total objects drawn this frame.
    pub objects_drawn: i32,
    /// Number of material changes this frame.
    pub material_changes: i32,
    /// Number of shader changes this frame.
    pub shader_changes: i32,
    /// Number of surface changes this frame.
    pub surface_changes: i32,
    /// Number of vertices drawn this frame.
    pub verts_drawn: i32,
}

impl GodotFrameStats {
    /// Serialize to JSON for TCP streaming.
    pub fn to_json(&self) -> String {
        format!(
            r#"{{"engine":"godot","draw_calls":{},"objects_drawn":{},"material_changes":{},"shader_changes":{},"surface_changes":{},"verts_drawn":{}}}"#,
            self.draw_calls,
            self.objects_drawn,
            self.material_changes,
            self.shader_changes,
            self.surface_changes,
            self.verts_drawn,
        )
    }

    /// Push these stats to the transport queue.
    pub fn queue_to_transport(&self) {
        let json = self.to_json();
        crate::transport::push_event_json(&json);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unity_frame_stats_default() {
        let stats = UnityFrameStats::default();
        assert_eq!(stats.draw_calls, 0);
        assert_eq!(stats.batches, 0);
        assert_eq!(stats.setpass_calls, 0);
        assert_eq!(stats.mono_heap_kb, 0);
        assert_eq!(stats.gc_alloc_kb, 0);
    }

    #[test]
    fn test_unity_frame_stats_to_json_contains_engine_tag() {
        let stats = UnityFrameStats {
            draw_calls: 150,
            batches: 80,
            setpass_calls: 45,
            mono_heap_kb: 262_144, // 256 MB
            gc_alloc_kb: 512,
            triangles: 50_000,
            vertices: 120_000,
        };
        let json = stats.to_json();
        assert!(json.contains(r#""engine":"unity""#));
        assert!(json.contains(r#""draw_calls":150"#));
        assert!(json.contains(r#""mono_heap_kb":262144"#));
    }

    #[test]
    fn test_unreal_frame_stats_to_json_contains_engine_tag() {
        let stats = UnrealFrameStats {
            rhi_frame_time_ms: 8.33,
            draw_primitive_calls: 2500,
            gpu_frame_time_ms: 7.5,
            stat_unit_json: r#"{"frame":8.33,"game":5.2,"draw":3.1,"gpu":7.5}"#.to_string(),
        };
        let json = stats.to_json();
        assert!(json.contains(r#""engine":"unreal""#));
        assert!(json.contains(r#""rhi_frame_time_ms":8.33"#));
        assert!(json.contains(r#""gpu_frame_time_ms":7.5"#));
    }

    #[test]
    fn test_godot_frame_stats_to_json_contains_engine_tag() {
        let stats = GodotFrameStats {
            draw_calls: 200,
            objects_drawn: 5000,
            material_changes: 35,
            shader_changes: 12,
            surface_changes: 45,
            verts_drawn: 150_000,
        };
        let json = stats.to_json();
        assert!(json.contains(r#""engine":"godot""#));
        assert!(json.contains(r#""draw_calls":200"#));
        assert!(json.contains(r#""verts_drawn":150000"#));
    }

    #[test]
    fn test_all_stats_serialize_valid_json() {
        let unity = UnityFrameStats {
            draw_calls: 1,
            batches: 1,
            setpass_calls: 1,
            mono_heap_kb: 1,
            gc_alloc_kb: 1,
            triangles: 1,
            vertices: 1,
        };
        let unreal = UnrealFrameStats {
            rhi_frame_time_ms: 1.0,
            draw_primitive_calls: 1,
            gpu_frame_time_ms: 1.0,
            stat_unit_json: "{}".to_string(),
        };
        let godot = GodotFrameStats {
            draw_calls: 1,
            objects_drawn: 1,
            material_changes: 1,
            shader_changes: 1,
            surface_changes: 1,
            verts_drawn: 1,
        };

        // All must be valid JSON (no panic on format!)
        assert!(!unity.to_json().is_empty());
        assert!(!unreal.to_json().is_empty());
        assert!(!godot.to_json().is_empty());
    }
}
