// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// PC metric collection modules for Windows profiling.
/// Pure Rust library code — no binary main. Ready for pb-pcprobe assembly.
///
/// Modules mirror UNIFIED-SPEC §19.2-19.4 and D-09/D-11:
/// - pdh: Performance Data Helper counter framework
/// - dxgi: DXGI Present hook (Detours injection + PresentMon fallback)
/// - etw: ETW frame timing session for non-DX games
/// - memory: Working set, private bytes, GPU committed memory
/// - cpu: Per-process/thread CPU, frequency via WMI
/// - disk_io: Per-process disk I/O rates
/// - gpu: GPU utilization and memory via PDH
/// - network: Per-interface network I/O rates

pub mod pdh;
pub mod dxgi;
pub mod etw;
pub mod memory;
pub mod cpu;
pub mod disk_io;
pub mod gpu;
pub mod network;
pub mod collector;
