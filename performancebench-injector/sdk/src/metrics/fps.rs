//! FPS metric collection via Choreographer frame callback hook.
//!
//! Compute FPS as 1e9 / avg_frame_delta_ns over a 1-second window.
//! Classify jank: frame delta > 2x vsync period = small jank, > 4x = big jank.
//!
//! Output fields: fps, jank_count, jank_small_count, jank_big_count,
//! jank_ratio_count, frametimes_json.

const VSYNC_NS: u64 = 16_666_667; // ~16.67ms for 60Hz
const JANK_SMALL_MULTIPLIER: u64 = 2;
const JANK_BIG_MULTIPLIER: u64 = 4;

/// Result of FPS computation including jank classification.
#[derive(Debug, Clone)]
pub struct FpsResult {
    pub fps: f64,
    pub jank_count: i32,
    pub jank_small_count: i32,
    pub jank_big_count: i32,
    pub jank_ratio_count: i32,
    pub frametimes_json: String,
}

/// Compute FPS from a series of frame timestamps in nanoseconds.
/// FPS = 1e9 / avg_frame_delta_ns over the given window.
/// Returns 0.0 for empty input.
pub fn compute_fps(frame_deltas_ns: &[u64]) -> f64 {
    if frame_deltas_ns.is_empty() {
        return 0.0;
    }

    let total_ns: u64 = frame_deltas_ns.iter().sum();
    let count = frame_deltas_ns.len() as f64;
    let avg_delta = total_ns as f64 / count;

    if avg_delta <= 0.0 {
        return 0.0;
    }

    1_000_000_000.0 / avg_delta
}

/// Classify jank from frame deltas against the VSYNC period.
/// Returns (total_jank_count, small_jank_count, big_jank_count).
pub fn classify_jank(frame_deltas_ns: &[u64]) -> (i32, i32, i32) {
    let jank_small = VSYNC_NS * JANK_SMALL_MULTIPLIER;
    let jank_big = VSYNC_NS * JANK_BIG_MULTIPLIER;

    let mut small = 0;
    let mut big = 0;

    for &delta in frame_deltas_ns {
        if delta > jank_big {
            big += 1;
        } else if delta > jank_small {
            small += 1;
        }
    }

    (small + big, small, big)
}

/// Build frametimes JSON array from frame deltas in nanoseconds.
/// Converts to milliseconds and returns last N entries as JSON.
pub fn build_frametimes_json(frame_deltas_ns: &[u64], max_entries: usize) -> String {
    let count = frame_deltas_ns.len().min(max_entries);
    let start = frame_deltas_ns.len().saturating_sub(count);

    let frametimes_ms: Vec<f64> = frame_deltas_ns[start..]
        .iter()
        .map(|&ns| ns as f64 / 1_000_000.0)
        .collect();

    serde_json::to_string(&frametimes_ms).unwrap_or_else(|_| "[]".into())
}

/// Run full FPS analysis on a set of frame deltas.
pub fn analyze_fps(frame_deltas_ns: &[u64]) -> FpsResult {
    let fps = compute_fps(frame_deltas_ns);
    let (jank_count, jank_small_count, jank_big_count) = classify_jank(frame_deltas_ns);
    let jank_ratio_count = if frame_deltas_ns.is_empty() {
        0
    } else {
        ((jank_count as f64 / frame_deltas_ns.len() as f64) * 100.0) as i32
    };
    let frametimes_json = build_frametimes_json(frame_deltas_ns, 60);

    FpsResult {
        fps,
        jank_count,
        jank_small_count,
        jank_big_count,
        jank_ratio_count,
        frametimes_json,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_compute_fps_60fps() {
        let deltas: Vec<u64> = vec![16_666_667; 60];
        let fps = compute_fps(&deltas);
        assert!(fps > 55.0 && fps < 65.0, "Expected ~60 fps, got {}", fps);
    }

    #[test]
    fn test_compute_fps_30fps() {
        let deltas: Vec<u64> = vec![33_333_333; 30];
        let fps = compute_fps(&deltas);
        assert!(fps > 28.0 && fps < 32.0, "Expected ~30 fps, got {}", fps);
    }

    #[test]
    fn test_compute_fps_empty() {
        assert_eq!(compute_fps(&[]), 0.0);
    }

    #[test]
    fn test_no_jank_at_60fps() {
        let deltas = vec![16_666_667; 60];
        let (total, small, big) = classify_jank(&deltas);
        assert_eq!(total, 0);
        assert_eq!(small, 0);
        assert_eq!(big, 0);
    }

    #[test]
    fn test_small_jank() {
        let mut deltas = vec![16_666_667; 60];
        deltas[10] = 50_000_000; // > 2x vsync
        let (total, small, big) = classify_jank(&deltas);
        assert_eq!(small, 1);
        assert_eq!(big, 0);
        assert_eq!(total, 1);
    }

    #[test]
    fn test_big_jank() {
        let mut deltas = vec![16_666_667; 60];
        deltas[20] = 100_000_000; // > 4x vsync
        let (total, small, big) = classify_jank(&deltas);
        assert_eq!(small, 0);
        assert_eq!(big, 1);
        assert_eq!(total, 1);
    }

    #[test]
    fn test_frametimes_json() {
        let deltas = vec![16_666_667, 33_333_333, 50_000_000];
        let json = build_frametimes_json(&deltas, 10);
        let parsed: Vec<f64> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), 3);
        assert!((parsed[0] - 16.667).abs() < 0.01);
        assert!((parsed[1] - 33.333).abs() < 0.01);
        assert!((parsed[2] - 50.0).abs() < 0.01);
    }
}
