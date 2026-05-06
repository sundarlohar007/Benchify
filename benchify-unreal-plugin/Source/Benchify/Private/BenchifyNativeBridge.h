// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyNativeBridge.h — Internal header for native library loading.
// Not exposed in Public/ — plugin-internal use only.

#pragma once

#include "CoreMinimal.h"

/**
 * Internal native bridge managing the Rust benchify_engine dynamic library.
 * Handles load/unload and function pointer resolution.
 * Per-platform .dll/.dylib/.so discovery from known plugin paths.
 */
struct BENCHIFY_API FBenchifyNativeBridge
{
    /** Initialize: load native library and resolve function pointers. */
    static bool Initialize();

    /** Shutdown: unload native library. */
    static void Shutdown();

    /** Check if native library is loaded and functional. */
    static bool IsLoaded();

    /** Call benchify_engine_begin_marker (FFI). */
    static void BeginMarker(const FString& Name);

    /** Call benchify_engine_end_marker (FFI). */
    static void EndMarker();

    /** Call benchify_engine_queue_frame_stats (FFI). */
    static void QueueFrameStats(const FString& Json);
};
