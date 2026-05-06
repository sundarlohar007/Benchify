// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify

using UnrealBuildTool;

public class BenchifyEditor : ModuleRules
{
    public BenchifyEditor(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "Benchify"
        });

        PrivateDependencyModuleNames.AddRange(new string[]
        {
            "Slate",
            "SlateCore",
            "UnrealEd",
            "EditorStyle",
            "EditorWidgets",
            "EditorSubsystem"
        });
    }
}
