/// Auto-marker triggers for game engine scene/application lifecycle events.
///
/// Per D-01: Auto-marker logic in shared Rust core.
/// Engine wrappers (Unity/Unreal/Godot) call these on scene loads, app start, etc.
///
/// MIT License — Copyright (c) 2026 Benchify

use crate::engine_core::marker::{begin_scene_marker, end_marker};

/// Called when a scene/map/level loads in the game engine.
/// Creates a scoped marker pair for the scene transition.
/// The scene_name is used in marker JSON for timeline identification.
pub fn on_scene_load(scene_name: &str) -> Option<String> {
    let mut marker = begin_scene_marker(scene_name);

    // Scene transitions are typically instantaneous in editor,
    // so end immediately with zero duration.
    // Engine wrappers may call end_scene_marker separately if needed.
    let json = crate::engine_core::marker::marker_event_json(&marker);
    end_marker(&mut marker);

    // Push the completed marker to the transport queue.
    crate::transport::push_event_json(&json);

    Some(json)
}

/// Called when the application/game starts.
/// Emits an "App Launch" marker for session timeline.
pub fn on_app_start() -> String {
    let marker = crate::engine_core::marker::begin_marker("App Launch");
    let json = crate::engine_core::marker::marker_event_json(&marker);
    crate::transport::push_event_json(&json);
    json
}

/// Called when the application/game is paused or backgrounded.
pub fn on_app_pause() -> String {
    let marker = crate::engine_core::marker::begin_marker("App Pause");
    let json = crate::engine_core::marker::marker_event_json(&marker);
    crate::transport::push_event_json(&json);
    json
}

/// Called when the application/game resumes or comes to foreground.
pub fn on_app_resume() -> String {
    let marker = crate::engine_core::marker::begin_marker("App Resume");
    let json = crate::engine_core::marker::marker_event_json(&marker);
    crate::transport::push_event_json(&json);
    json
}

/// Called when a user-defined marker is created.
/// Wraps begin/end marker pattern with auto-push to transport.
pub fn on_user_marker(name: &str) -> String {
    let marker = crate::engine_core::marker::begin_marker(name);
    let json = crate::engine_core::marker::marker_event_json(&marker);
    crate::transport::push_event_json(&json);
    json
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scene_loaded_triggers_marker_pair() {
        let result = on_scene_load("MainMenu");
        assert!(result.is_some());
        let json = result.unwrap();
        assert!(json.contains(r#""type":"marker""#));
        assert!(json.contains("MainMenu"));
        assert!(json.contains(r#""scene":""#));
    }

    #[test]
    fn test_app_start_emits_launch_marker() {
        let json = on_app_start();
        assert!(json.contains("App Launch"));
        assert!(json.contains(r#""type":"marker""#));
    }

    #[test]
    fn test_app_pause_resume_markers() {
        let pause_json = on_app_pause();
        assert!(pause_json.contains("App Pause"));

        let resume_json = on_app_resume();
        assert!(resume_json.contains("App Resume"));
    }

    #[test]
    fn test_user_marker_name_preserved() {
        let json = on_user_marker("boss_fight_phase2");
        assert!(json.contains("boss_fight_phase2"));
    }
}
