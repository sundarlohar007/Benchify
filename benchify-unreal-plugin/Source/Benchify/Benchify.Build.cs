// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify

using UnrealBuildTool;
using System.IO;

public class Benchify : ModuleRules
{
    public Benchify(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "Slate",
            "SlateCore",
            "RHI",
            "RenderCore"
        });

        PrivateDependencyModuleNames.AddRange(new string[] { });

        // Link Rust benchify_engine native library per platform.
        string PluginDir = ModuleDirectory + "/../..";
        string BinariesDir = Path.Combine(PluginDir, "Binaries");

        if (Target.Platform == UnrealTargetPlatform.Win64)
        {
            PublicAdditionalLibraries.Add(Path.Combine(BinariesDir, "Win64", "benchify_engine.dll.lib"));
            RuntimeDependencies.Add(Path.Combine(BinariesDir, "Win64", "benchify_engine.dll"));
        }
        else if (Target.Platform == UnrealTargetPlatform.Mac)
        {
            PublicAdditionalLibraries.Add(Path.Combine(BinariesDir, "Mac", "libbenchify_engine.dylib"));
            RuntimeDependencies.Add(Path.Combine(BinariesDir, "Mac", "libbenchify_engine.dylib"));
        }
        else if (Target.Platform == UnrealTargetPlatform.Linux)
        {
            PublicAdditionalLibraries.Add(Path.Combine(BinariesDir, "Linux", "libbenchify_engine.so"));
            RuntimeDependencies.Add(Path.Combine(BinariesDir, "Linux", "libbenchify_engine.so"));
        }
    }
}
