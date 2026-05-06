// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyNativeBridge.cpp — C FFI bridge to Rust benchify_engine native library.
// Per D-01: extern "C" wrapper calling Rust engine_core FFI exports.
// Threat mitigation (T-05-01, T-05-04): Loads from known plugin paths only — no PATH search.

#include "BenchifyNativeBridge.h"
#include "HAL/PlatformProcess.h"
#include "Misc/Paths.h"
#include "Logging/LogMacros.h"

DEFINE_LOG_CATEGORY_STATIC(LogBenchify, Log, All);

// Native library handle
static void* BenchifyEngineHandle = nullptr;

// Function pointer types matching Rust FFI exports
typedef void (*BenchifyBeginMarkerFn)(const char* name);
typedef void (*BenchifyEndMarkerFn)();
typedef void (*BenchifyQueueFrameStatsFn)(const char* json);

// Loaded function pointers
static BenchifyBeginMarkerFn BenchifyBeginMarker = nullptr;
static BenchifyEndMarkerFn BenchifyEndMarker = nullptr;
static BenchifyQueueFrameStatsFn BenchifyQueueFrameStats = nullptr;

bool FBenchifyNativeBridge::Initialize()
{
    if (IsLoaded()) return true;

#if PLATFORM_WINDOWS
    FString LibName = TEXT("benchify_engine.dll");
    FString LibPath = FPaths::Combine(FPaths::ProjectPluginsDir(), TEXT("Benchify/Binaries/Win64"), LibName);
#elif PLATFORM_MAC
    FString LibName = TEXT("libbenchify_engine.dylib");
    FString LibPath = FPaths::Combine(FPaths::ProjectPluginsDir(), TEXT("Benchify/Binaries/Mac"), LibName);
#elif PLATFORM_LINUX
    FString LibName = TEXT("libbenchify_engine.so");
    FString LibPath = FPaths::Combine(FPaths::ProjectPluginsDir(), TEXT("Benchify/Binaries/Linux"), LibName);
#else
    UE_LOG(LogBenchify, Warning, TEXT("Benchify: Unsupported platform"));
    return false;
#endif

    BenchifyEngineHandle = FPlatformProcess::GetDllHandle(*LibPath);
    if (!BenchifyEngineHandle)
    {
        UE_LOG(LogBenchify, Warning, TEXT("Benchify: Failed to load native library from %s"), *LibPath);
        return false;
    }

    // Resolve function pointers
    BenchifyBeginMarker = (BenchifyBeginMarkerFn)FPlatformProcess::GetDllExport(BenchifyEngineHandle, TEXT("benchify_engine_begin_marker"));
    BenchifyEndMarker = (BenchifyEndMarkerFn)FPlatformProcess::GetDllExport(BenchifyEngineHandle, TEXT("benchify_engine_end_marker"));
    BenchifyQueueFrameStats = (BenchifyQueueFrameStatsFn)FPlatformProcess::GetDllExport(BenchifyEngineHandle, TEXT("benchify_engine_queue_frame_stats"));

    if (!BenchifyBeginMarker || !BenchifyEndMarker || !BenchifyQueueFrameStats)
    {
        UE_LOG(LogBenchify, Warning, TEXT("Benchify: Failed to resolve native exports"));
        Shutdown();
        return false;
    }

    UE_LOG(LogBenchify, Log, TEXT("Benchify: Native library loaded successfully"));
    return true;
}

void FBenchifyNativeBridge::Shutdown()
{
    if (BenchifyEngineHandle)
    {
        FPlatformProcess::FreeDllHandle(BenchifyEngineHandle);
        BenchifyEngineHandle = nullptr;
    }
    BenchifyBeginMarker = nullptr;
    BenchifyEndMarker = nullptr;
    BenchifyQueueFrameStats = nullptr;
}

bool FBenchifyNativeBridge::IsLoaded()
{
    return BenchifyEngineHandle != nullptr;
}

void FBenchifyNativeBridge::BeginMarker(const FString& Name)
{
    if (!BenchifyBeginMarker) return;
    FTCHARToUTF8 Converter(*Name);
    BenchifyBeginMarker(Converter.Get());
}

void FBenchifyNativeBridge::EndMarker()
{
    if (!BenchifyEndMarker) return;
    BenchifyEndMarker();
}

void FBenchifyNativeBridge::QueueFrameStats(const FString& Json)
{
    if (!BenchifyQueueFrameStats) return;
    FTCHARToUTF8 Converter(*Json);
    BenchifyQueueFrameStats(Converter.Get());
}
