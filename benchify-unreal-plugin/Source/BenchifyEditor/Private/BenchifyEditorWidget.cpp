// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// BenchifyEditorWidget.cpp — Slate widget implementation.
// Per D-03: Read-only stats: RHI frame time, GPU time, draw primitives, FPS badge.

#include "BenchifyEditorWidget.h"
#include "BenchifySubsystem.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SScrollBox.h"
#include "Widgets/Text/STextBlock.h"
#include "Widgets/Input/SButton.h"
#include "EditorStyleSet.h"
#include "Engine/Engine.h"

#define LOCTEXT_NAMESPACE "BenchifyEditor"

void SBenchifyEditorWidget::Construct(const FArguments& InArgs)
{
    ChildSlot
    [
        BuildStatsPanel()
    ];
}

TSharedRef<SWidget> SBenchifyEditorWidget::BuildStatsPanel()
{
    return SNew(SBorder)
        .BorderImage(FAppStyle::GetBrush("ToolPanel.GroupBorder"))
        .Padding(8.0f)
        [
            SNew(SScrollBox)
            + SScrollBox::Slot()
            .Padding(4)
            [
                SNew(SVerticalBox)

                // Title
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 0, 0, 8)
                [
                    SNew(STextBlock)
                    .Text(LOCTEXT("BenchifyTitle", "Benchify Profiler"))
                    .Font(FAppStyle::GetFontStyle("HeadingMedium"))
                ]

                // FPS display
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 4)
                [
                    SNew(SHorizontalBox)
                    + SHorizontalBox::Slot()
                    .AutoWidth()
                    [
                        SNew(STextBlock)
                        .Text(LOCTEXT("FpsLabel", "FPS: "))
                        .Font(FAppStyle::GetFontStyle("NormalText"))
                    ]
                    + SHorizontalBox::Slot()
                    .AutoWidth()
                    [
                        SNew(STextBlock)
                        .Text(this, &SBenchifyEditorWidget::GetFpsText)
                        .Font(FAppStyle::GetFontStyle("NormalFontBold"))
                    ]
                ]

                // RHI Frame Time
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 2)
                [
                    SNew(STextBlock)
                    .Text(LOCTEXT("RhiFrameTime", "RHI Frame Time: -- ms"))
                    .Font(FAppStyle::GetFontStyle("NormalText"))
                ]

                // GPU Frame Time
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 2)
                [
                    SNew(STextBlock)
                    .Text(LOCTEXT("GpuFrameTime", "GPU Frame Time: -- ms"))
                    .Font(FAppStyle::GetFontStyle("NormalText"))
                ]

                // Draw Primitive Calls
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 2)
                [
                    SNew(STextBlock)
                    .Text(LOCTEXT("DrawPrimitives", "Draw Primitives: --"))
                    .Font(FAppStyle::GetFontStyle("NormalText"))
                ]

                // Spacer
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 12)
                [
                    SNew(SBox)
                    .HeightOverride(1)
                ]

                // Open Desktop App button
                + SVerticalBox::Slot()
                .AutoHeight()
                .Padding(0, 4)
                [
                    SNew(SButton)
                    .Text(LOCTEXT("OpenDesktopApp", "Open PerformanceBench Desktop"))
                    .HAlign(HAlign_Center)
                    .OnClicked_Lambda([]() -> FReply
                    {
                        FPlatformProcess::LaunchURL(
                            TEXT("https://github.com/sundarlohar007/Benchify"),
                            nullptr, nullptr
                        );
                        return FReply::Handled();
                    })
                ]
            ]
        ];
}

FText SBenchifyEditorWidget::GetFpsText() const
{
    if (GEngine)
    {
        UBenchifySubsystem* Subsystem = GEngine->GetEngineSubsystem<UBenchifySubsystem>();
        if (Subsystem)
        {
            float Fps = Subsystem->GetCurrentFps();
            if (Fps > 0.0f)
            {
                return FText::FromString(FString::Printf(TEXT("%.1f"), Fps));
            }
        }
    }
    return LOCTEXT("FpsUnavailable", "--");
}

FLinearColor SBenchifyEditorWidget::GetFpsColor(float Fps) const
{
    if (Fps >= 55.0f) return FLinearColor::Green;
    if (Fps >= 30.0f) return FLinearColor::Yellow;
    return FLinearColor::Red;
}

void SBenchifyEditorWidget::RefreshStats()
{
    // Stats are pulled on-demand via attribute bindings in slate.
    // This method would be called periodically during PIE to refresh.
}

#undef LOCTEXT_NAMESPACE
