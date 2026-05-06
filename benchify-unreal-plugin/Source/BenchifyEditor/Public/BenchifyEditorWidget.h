// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyEditorWidget.h — Slate editor widget for Benchify Profiler.
// Per D-03: Read-only stats dashboard accessible via Window > Benchify Profiler.
// Shows RHI frame time, GPU time, draw primitives, FPS badge during PIE.

#pragma once

#include "CoreMinimal.h"
#include "Widgets/SCompoundWidget.h"
#include "Widgets/DeclarativeSyntaxSupport.h"

/**
 * Slate widget displaying live Benchify profiling stats during PIE.
 * Accessible from Window menu as a dockable tab.
 */
class BENCHIFYEDITOR_API SBenchifyEditorWidget : public SCompoundWidget
{
public:
    SLATE_BEGIN_ARGS(SBenchifyEditorWidget) {}
    SLATE_END_ARGS()

    /** Construct the widget layout. */
    void Construct(const FArguments& InArgs);

private:
    /** Build the stats display UI. */
    TSharedRef<SWidget> BuildStatsPanel();

    /** Refresh displayed stats. Called on tick during PIE. */
    void RefreshStats();

    /** Get FPS color: green >= 55, yellow >= 30, red < 30. */
    FLinearColor GetFpsColor(float Fps) const;

    /** Handle for editor tick registration. */
    FDelegateHandle TickHandle;
};
