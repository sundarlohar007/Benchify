// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! Chunk manager for PC video recording.
//!
//! Manages 5-minute chunk rotation (per §32.3), tracks chunk metadata,
//! and generates concat lists and JSON metadata matching the videos table schema.
//!
//! Chunk naming: `chunk_{index:03}.h264` (raw H.264 NALs).
//! Output directory: `{output_dir}/{session_id}/`.

use std::path::{Path, PathBuf};
use std::time::SystemTime;

/// Manages video chunk rotation and metadata.
#[derive(Debug, Clone)]
pub struct ChunkManager {
    /// Output directory root.
    pub output_dir: PathBuf,

    /// Session ID (used for subdirectory naming).
    pub session_id: String,

    /// Maximum duration per chunk in milliseconds (default 300000 = 5 min).
    pub chunk_max_ms: u64,

    /// Completed chunk records.
    pub chunks: Vec<ChunkRecord>,

    /// Current chunk index (starts at 0 for first chunk).
    pub current_index: u32,

    /// Session start time.
    pub session_start: SystemTime,
}

/// Record for a single completed video chunk.
#[derive(Debug, Clone)]
pub struct ChunkRecord {
    /// Chunk file name (e.g., "chunk_000.h264").
    pub file: String,

    /// Offset from session start in milliseconds.
    pub start_ms: u64,

    /// Duration of this chunk in milliseconds.
    pub duration_ms: u64,
}

impl ChunkManager {
    /// Create a new chunk manager.
    ///
    /// Creates the output directory `{output_dir}/{session_id}/` if it
    /// doesn't exist.
    ///
    /// # Arguments
    /// * `output_dir` - Root output directory path.
    /// * `session_id` - Session identifier for subdirectory.
    /// * `chunk_max_ms` - Maximum chunk duration in ms (300000 = 5 min).
    pub fn new(output_dir: &Path, session_id: &str, chunk_max_ms: u64) -> Self {
        let session_dir = output_dir.join(session_id);

        // Create output directory if it doesn't exist
        if let Err(e) = std::fs::create_dir_all(&session_dir) {
            log::warn!("Failed to create video output directory {:?}: {}", session_dir, e);
        }

        Self {
            output_dir: output_dir.to_path_buf(),
            session_id: session_id.to_string(),
            chunk_max_ms,
            chunks: Vec::new(),
            current_index: 0,
            session_start: SystemTime::now(),
        }
    }

    /// Open the next chunk for writing.
    ///
    /// Increments `current_index` and returns the full path for the new chunk.
    /// The chunk file should be opened by the caller for raw H.264 writing.
    ///
    /// Returns the full path to `chunk_{index:03}.h264`.
    pub fn open_next_chunk(&mut self) -> PathBuf {
        self.current_index += 1;
        self.chunk_path(self.current_index)
    }

    /// Called when a chunk completes (duration reached or recording stopped).
    ///
    /// Records the chunk in the completed chunks list.
    ///
    /// # Arguments
    /// * `duration_ms` - Actual duration of the completed chunk.
    pub fn on_chunk_complete(&mut self, duration_ms: u64) {
        let chunk_idx = self.current_index;
        let file_name = chunk_filename(chunk_idx);

        // Calculate start offset from session start
        let start_ms = self
            .chunks
            .last()
            .map(|c| c.start_ms + c.duration_ms)
            .unwrap_or(0);

        self.chunks.push(ChunkRecord {
            file: file_name,
            start_ms,
            duration_ms,
        });

        log::debug!(
            "Chunk {} complete: {}ms (offset {}ms)",
            chunk_idx,
            duration_ms,
            start_ms
        );
    }

    /// Build ffmpeg concat demuxer format file content.
    ///
    /// Returns a string suitable for writing to a concat list file:
    /// ```
    /// file 'chunk_000.h264'
    /// file 'chunk_001.h264'
    /// ```
    pub fn build_concat_list(&self) -> String {
        self.chunks
            .iter()
            .map(|c| format!("file '{}'", c.file))
            .collect::<Vec<_>>()
            .join("\n")
    }

    /// Get chunks as JSON array matching videos table `chunks_json` format.
    ///
    /// Returns: `[{"file":"chunk_000.h264","start_ms":0,"duration_ms":175000},...]`
    pub fn get_chunks_json(&self) -> String {
        let entries: Vec<serde_json::Value> = self
            .chunks
            .iter()
            .map(|c| {
                serde_json::json!({
                    "file": c.file,
                    "start_ms": c.start_ms,
                    "duration_ms": c.duration_ms,
                })
            })
            .collect();

        serde_json::to_string(&entries).unwrap_or_else(|_| "[]".to_string())
    }

    /// Get inter-chunk gaps as JSON array of durations in ms.
    ///
    /// Computes gaps between consecutive chunk end and start times.
    /// A gap of 0 means perfect continuity.
    pub fn get_gaps_json(&self) -> String {
        let gaps: Vec<u64> = self.compute_gaps();
        serde_json::to_string(&gaps).unwrap_or_else(|_| "[]".to_string())
    }

    /// Compute inter-chunk gaps in milliseconds.
    fn compute_gaps(&self) -> Vec<u64> {
        let mut gaps = Vec::new();

        for window in self.chunks.windows(2) {
            let prev = &window[0];
            let next = &window[1];
            let prev_end = prev.start_ms + prev.duration_ms;
            if next.start_ms > prev_end {
                gaps.push(next.start_ms - prev_end);
            } else {
                gaps.push(0); // Overlap or exact continuity
            }
        }

        gaps
    }

    /// Get the file path for a given chunk index.
    fn chunk_path(&self, index: u32) -> PathBuf {
        let session_dir = self.output_dir.join(&self.session_id);
        session_dir.join(chunk_filename(index))
    }
}

/// Generate chunk file name for an index (1-based: chunk_001.h264).
fn chunk_filename(index: u32) -> String {
    format!("chunk_{:03}.h264", index)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_output_dir() -> (tempfile::TempDir, PathBuf) {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().to_path_buf();
        (dir, path)
    }

    #[test]
    fn test_chunk_manager_new_creates_directory() {
        let (_dir, path) = temp_output_dir();
        let mgr = ChunkManager::new(&path, "session_001", 300_000);
        let session_dir = path.join("session_001");
        assert!(session_dir.exists(), "Session directory should be created");
        assert_eq!(mgr.chunks.len(), 0);
        assert_eq!(mgr.current_index, 0);
        assert_eq!(mgr.chunk_max_ms, 300_000);
    }

    #[test]
    fn test_open_next_chunk_returns_correct_path() {
        let (_dir, path) = temp_output_dir();
        let mut mgr = ChunkManager::new(&path, "session_001", 300_000);

        let chunk1 = mgr.open_next_chunk();
        assert_eq!(mgr.current_index, 1);
        assert!(chunk1.to_string_lossy().contains("chunk_001.h264"));

        let chunk2 = mgr.open_next_chunk();
        assert_eq!(mgr.current_index, 2);
        assert!(chunk2.to_string_lossy().contains("chunk_002.h264"));
    }

    #[test]
    fn test_on_chunk_complete_records_metadata() {
        let (_dir, path) = temp_output_dir();
        let mut mgr = ChunkManager::new(&path, "session_001", 300_000);

        // First chunk
        let _ = mgr.open_next_chunk();
        mgr.on_chunk_complete(295_000);
        assert_eq!(mgr.chunks.len(), 1);
        assert_eq!(mgr.chunks[0].start_ms, 0);
        assert!((mgr.chunks[0].duration_ms - 295_000) < 1000);

        // Second chunk
        let _ = mgr.open_next_chunk();
        mgr.on_chunk_complete(290_000);
        assert_eq!(mgr.chunks.len(), 2);
        assert!((mgr.chunks[1].start_ms - 295_000) < 1000);
        assert!((mgr.chunks[1].duration_ms - 290_000) < 1000);
    }

    #[test]
    fn test_build_concat_list_format() {
        let (_dir, path) = temp_output_dir();
        let mut mgr = ChunkManager::new(&path, "session_001", 300_000);

        let _ = mgr.open_next_chunk();
        mgr.chunks.push(ChunkRecord {
            file: "chunk_001.h264".to_string(),
            start_ms: 0,
            duration_ms: 295_000,
        });
        let _ = mgr.open_next_chunk();
        mgr.chunks.push(ChunkRecord {
            file: "chunk_002.h264".to_string(),
            start_ms: 295_000,
            duration_ms: 290_000,
        });

        let concat = mgr.build_concat_list();
        let expected = "file 'chunk_001.h264'\nfile 'chunk_002.h264'";
        assert_eq!(concat, expected);
    }

    #[test]
    fn test_get_chunks_json_format() {
        let (_dir, path) = temp_output_dir();
        let mut mgr = ChunkManager::new(&path, "session_001", 300_000);

        mgr.chunks.push(ChunkRecord {
            file: "chunk_001.h264".to_string(),
            start_ms: 0,
            duration_ms: 175_000,
        });

        let json = mgr.get_chunks_json();
        assert!(json.contains("chunk_001.h264"));
        assert!(json.contains("start_ms"));
        assert!(json.contains("duration_ms"));
        assert!(json.contains("175000"));

        // Should be valid JSON
        let _: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
    }

    #[test]
    fn test_get_gaps_json() {
        let (_dir, path) = temp_output_dir();
        let mut mgr = ChunkManager::new(&path, "session_001", 300_000);

        // No chunks -> empty gaps
        assert_eq!(mgr.get_gaps_json(), "[]");

        // Two chunks with a 5ms gap
        mgr.chunks.push(ChunkRecord {
            file: "chunk_001.h264".to_string(),
            start_ms: 0,
            duration_ms: 295_000,
        });
        mgr.chunks.push(ChunkRecord {
            file: "chunk_002.h264".to_string(),
            start_ms: 295_005, // 5ms gap
            duration_ms: 290_000,
        });

        let gaps: Vec<u64> = serde_json::from_str(&mgr.get_gaps_json()).unwrap();
        assert_eq!(gaps.len(), 1);
        assert_eq!(gaps[0], 5);
    }

    #[test]
    fn test_chunk_naming_matches_videos_schema() {
        // Verify chunk naming pattern matches existing videos table convention
        assert_eq!(chunk_filename(1), "chunk_001.h264");
        assert_eq!(chunk_filename(10), "chunk_010.h264");
        assert_eq!(chunk_filename(999), "chunk_999.h264");
    }

    #[test]
    fn test_chunk_manager_default_values() {
        let (_dir, path) = temp_output_dir();
        let mgr = ChunkManager::new(&path, "default_test", 300_000);
        assert_eq!(mgr.current_index, 0);
        assert!(mgr.chunks.is_empty());
        assert_eq!(mgr.chunk_max_ms, 300_000);
    }
}
