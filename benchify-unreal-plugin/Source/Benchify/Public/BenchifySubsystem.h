// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifySubsystem.h — UEngineSubsystem for Benchify Profiler.
// Per D-01: Auto-instantiated by engine. Binds PostLoadMapWithWorld for auto-markers.
// Per D-03: Collects per-frame RHI stats during PIE.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/EngineSubsystem.h"
#include "BenchifySubsystem.generated.h"

/**
 * Engine-level subsystem for Benchify profiling.
 * Automatically created by Unreal Engine at startup.
 * Subscribes to map load delegates for auto-markers.
 * Collects RHI/GPU frame stats during Play In Editor.
 */
UCLASS()
class BENCHIFY_API UBenchifySubsystem : public UEngineSubsystem
{
    GENERATED_BODY()

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;

    /** Called every frame for stat collection during PIE. */
    void Tick(float DeltaTime);

    /** Get the latest collected frame stats as JSON. */
    FString GetLatestFrameStatsJson() const;

    /** Get current FPS estimate (rolling 1s window). */
    float GetCurrentFps() const { return CurrentFps; }

private:
    /** Called when a map/world is loaded. Creates auto-marker. */
    void OnMapLoaded(UWorld* World);

    /** Collect RHI and GPU stats for the current frame. */
    void CollectFrameStats(float DeltaTime);

    /** Latest RHI frame time in milliseconds. */
    float RhiFrameTimeMs = 0.0f;

    /** Latest GPU frame time in milliseconds. */
    float GpuFrameTimeMs = 0.0f;

    /** Latest draw primitive call count. */
    int32 DrawPrimitiveCalls = 0;

    /** Rolling FPS (1-second window). */
    float CurrentFps = 0.0f;

    /** Frame count for FPS calculation. */
    int32 FrameCount = 0;

    /** Accumulated time for 1Hz aggregation. */
    float FrameAccumTime = 0.0f;

    /** Latest frame stats as JSON string. */
    FString LatestFrameStatsJson;

    /** Map load delegate handle. */
    FDelegateHandle MapLoadDelegateHandle;
};
