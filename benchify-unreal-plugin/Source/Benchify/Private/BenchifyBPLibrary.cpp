// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyBPLibrary.cpp — Implementation of Blueprint Function Library.
// Per D-02: BeginMarker/EndMarker via native bridge to Rust engine_core.

#include "BenchifyBPLibrary.h"
#include "BenchifySubsystem.h"
#include "BenchifyNativeBridge.h"
#include "Engine/Engine.h"

void UBenchifyBPLibrary::BeginMarker(const FString& Name)
{
    if (Name.IsEmpty()) return;

    // Push to Rust engine_core via native FFI bridge.
    FBenchifyNativeBridge::BeginMarker(Name);
}

void UBenchifyBPLibrary::EndMarker()
{
    FBenchifyNativeBridge::EndMarker();
}

FString UBenchifyBPLibrary::GetFrameStatsJson()
{
    // Delegate to engine subsystem for latest stats.
    if (GEngine)
    {
        UBenchifySubsystem* Subsystem = GEngine->GetEngineSubsystem<UBenchifySubsystem>();
        if (Subsystem)
        {
            return Subsystem->GetLatestFrameStatsJson();
        }
    }
    return TEXT("{}");
}

bool UBenchifyBPLibrary::IsEngineLibraryLoaded()
{
    return FBenchifyNativeBridge::IsLoaded();
}
