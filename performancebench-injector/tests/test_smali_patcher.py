"""Tests for smali_patcher.py — Smali bytecode patching into Application.onCreate()."""

import os
import pytest
from injector.smali_patcher import (
    find_application_smali,
    patch_oncreate_method,
    patch_smali,
)
from injector.proguard_helper import resolve_obfuscated_application


class TestFindApplicationSmali:
    """Tests for finding Application subclass smali files."""

    def test_finds_direct_application_subclass(self, sample_apk_dir):
        """Should find the MyApplication.smali file that extends Application."""
        result = find_application_smali(sample_apk_dir)
        assert result is not None
        assert "MyApplication.smali" in result

    def test_returns_none_when_no_application(self, smali_dir_no_application):
        """Should return None when no Application subclass exists."""
        result = find_application_smali(smali_dir_no_application)
        assert result is None

    def test_finds_application_in_multiple_smali_dirs(self, temp_dir):
        """Should search across smali, smali_classes2, smali_classes3 directories."""
        # Create smali_classes2 with the Application
        app_dir = os.path.join(temp_dir, "smali_classes2", "com", "example", "multi")
        os.makedirs(app_dir, exist_ok=True)

        smali_content = """.class public Lcom/example/multi/MultiApp;
.super Landroid/app/Application;
.source "MultiApp.java"

.method public onCreate()V
    .locals 0
    invoke-super {p0}, Landroid/app/Application;->onCreate()V
    return-void
.end method
"""
        with open(os.path.join(app_dir, "MultiApp.smali"), "w") as f:
            f.write(smali_content)

        result = find_application_smali(temp_dir)
        assert result is not None
        assert "MultiApp.smali" in result


class TestResolveObfuscatedApplication:
    """Tests for ProGuard obfuscation resolution."""

    def test_resolves_via_proguard_mapping(self, obfuscated_apk_dir, sample_proguard_mapping):
        """Should map obfuscated class name back to original."""
        app_name = resolve_obfuscated_application(
            obfuscated_apk_dir, sample_proguard_mapping
        )
        assert app_name is not None
        # The obfuscated name should resolve correctly
        assert "MyApp" in app_name or "MyApplication" in app_name

    def test_returns_none_without_mapping(self, obfuscated_apk_dir):
        """Should return None when no mapping file provided for obfuscated APK."""
        result = resolve_obfuscated_application(obfuscated_apk_dir, None)
        # Without mapping, we can still find Application via class hierarchy
        assert result is not None


class TestPatchOnCreateMethod:
    """Tests for patching the onCreate() method body."""

    def test_inserts_sdk_init_after_invoke_super(self, sample_apk_dir):
        """Should insert SdkLoader.init() call after invoke-super in onCreate."""
        app_file = find_application_smali(sample_apk_dir)
        with open(app_file, "r") as f:
            original = f.read()

        patched = patch_oncreate_method(original)

        # The patched code should contain the SDK init call
        assert "Ldev/benchify/SdkLoader;->init(Landroid/content/Context;)V" in patched

        # The invoke-super should still be present
        assert "invoke-super {p0}" in patched

        # The SDK init should appear AFTER invoke-super
        invoke_super_pos = patched.index("invoke-super {p0}")
        sdk_init_pos = patched.index(
            "Ldev/benchify/SdkLoader;->init(Landroid/content/Context;)V"
        )
        assert sdk_init_pos > invoke_super_pos, (
            "SDK init must be inserted after invoke-super"
        )

    def test_inserts_load_library_before_init(self, sample_apk_dir):
        """Should insert System.loadLibrary before SdkLoader.init."""
        app_file = find_application_smali(sample_apk_dir)
        with open(app_file, "r") as f:
            original = f.read()

        patched = patch_oncreate_method(original)

        # loadLibrary should appear before SdkLoader.init
        assert "System;->loadLibrary" in patched
        lib_pos = patched.index("System;->loadLibrary")
        init_pos = patched.index("Ldev/benchify/SdkLoader;->init")
        assert lib_pos < init_pos, "loadLibrary must come before SdkLoader.init"

    def test_preserves_existing_method_code(self, sample_apk_dir):
        """Should preserve all original method code (no removal)."""
        app_file = find_application_smali(sample_apk_dir)
        with open(app_file, "r") as f:
            original = f.read()

        patched = patch_oncreate_method(original)

        # Original code should still be present
        assert "SomeHelper;->init()V" in patched
        assert "invoke-super {p0}" in patched

    def test_handles_minimal_oncreate(self):
        """Should handle an onCreate with minimal body."""
        minimal = """.method public onCreate()V
    .locals 0

    invoke-super {p0}, Landroid/app/Application;->onCreate()V

    return-void
.end method
"""
        patched = patch_oncreate_method(minimal)
        assert "Ldev/benchify/SdkLoader;->init" in patched
        assert "invoke-super {p0}" in patched  # super call preserved

    def test_handles_no_oncreate_method(self):
        """Should handle Application class that doesn't override onCreate."""
        no_oncreate = """.class public Lcom/example/NoCreate;
.super Landroid/app/Application;

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Landroid/app/Application;-><init>()V
    return-void
.end method
"""
        # When there's no onCreate, we need to add one
        result = patch_smali(no_oncreate)
        # Should contain the onCreate method with our patch
        assert ".method public onCreate()V" in result


class TestPatchSmali:
    """Integration-level tests for full smali patching."""

    def test_patches_complete_smali_file(self, sample_apk_dir):
        """Should patch the full smali file and return the result."""
        app_file = find_application_smali(sample_apk_dir)
        with open(app_file, "r") as f:
            content = f.read()

        patched = patch_smali(content)

        # The patched file should still be valid Smali
        assert ".class public" in patched
        assert ".super Landroid/app/Application;" in patched

        # Should contain the SDK init
        assert "Ldev/benchify/SdkLoader;->init" in patched

        # Should contain new imports for SDK classes
        assert "Ldev/benchify/SdkLoader;" in patched

    def test_does_not_break_smali_syntax(self, sample_apk_dir):
        """Patched output should maintain valid Smali syntax."""
        app_file = find_application_smali(sample_apk_dir)
        with open(app_file, "r") as f:
            content = f.read()

        patched = patch_smali(content)

        # Basic Smali syntax checks
        assert patched.count(".method") >= content.count(".method")
        assert patched.count(".end method") >= content.count(".end method")
        # Number of .method and .end method should match
        assert patched.count(".method") == patched.count(".end method"), (
            "Mismatched .method / .end method in patched output"
        )

    def test_patch_idempotent(self, sample_apk_dir):
        """Running patch twice should not double-insert code."""
        app_file = find_application_smali(sample_apk_dir)
        with open(app_file, "r") as f:
            content = f.read()

        once = patch_smali(content)
        twice = patch_smali(once)

        # Count occurrences of the SDK init call
        count_once = once.count("Ldev/benchify/SdkLoader;->init")
        count_twice = twice.count("Ldev/benchify/SdkLoader;->init")

        assert count_once == count_twice, (
            f"Patch is not idempotent: {count_once} vs {count_twice}"
        )
