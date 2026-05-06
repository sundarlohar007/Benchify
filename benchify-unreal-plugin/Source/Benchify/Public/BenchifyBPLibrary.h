// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyBPLibrary.h — Blueprint Function Library for Benchify Profiler.
// Per D-02: Exposes BeginMarker/EndMarker as BlueprintCallable nodes.
// Developers can use these in any Blueprint or C++ code.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "BenchifyBPLibrary.generated.h"

/**
 * Blueprint-accessible Benchify profiling API.
 *
 * Usage:
 *   C++:     UBenchifyBPLibrary::BeginMarker(TEXT("MyMarker"));
 *   Blueprint: Call "BeginMarker" node in any Blueprint graph.
 */
UCLASS()
class BENCHIFY_API UBenchifyBPLibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /**
     * Begin a named scoped performance marker.
     * Pushes marker start to the Rust engine_core via native bridge.
     * Call EndMarker when the scope completes.
     *
     * @param Name Human-readable marker name (appears in desktop timeline).
     */
    UFUNCTION(BlueprintCallable, Category = "Benchify|Profiling",
        meta = (DisplayName = "Begin Marker", Keywords = "benchify profile marker"))
    static void BeginMarker(const FString& Name);

    /**
     * End the current scoped performance marker.
     * Records duration and pushes to desktop timeline via TCP.
     */
    UFUNCTION(BlueprintCallable, Category = "Benchify|Profiling",
        meta = (DisplayName = "End Marker", Keywords = "benchify profile marker"))
    static void EndMarker();

    /**
     * Get the current frame's profiling stats as a JSON string.
     * Matches engine_core::metrics::UnrealFrameStats format.
     *
     * @return JSON string with RHI frame time, draw calls, GPU time, Stat Unit data.
     */
    UFUNCTION(BlueprintCallable, Category = "Benchify|Profiling",
        meta = (DisplayName = "Get Frame Stats JSON", Keywords = "benchify profile stats"))
    static FString GetFrameStatsJson();

    /**
     * Check if the Benchify native engine library is loaded.
     * Plugin degrades gracefully if unavailable (per D-05).
     */
    UFUNCTION(BlueprintCallable, Category = "Benchify|Profiling")
    static bool IsEngineLibraryLoaded();
};
