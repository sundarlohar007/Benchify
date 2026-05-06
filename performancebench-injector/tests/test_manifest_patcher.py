"""Tests for manifest_patcher.py — AndroidManifest.xml modifications."""

import os
import pytest
from injector.manifest_patcher import patch_manifest, ManifestPatchResult


class TestPatchManifest:
    """Tests for AndroidManifest.xml patching."""

    def test_adds_required_permissions(self, sample_apk_dir):
        """Should add SYSTEM_ALERT_WINDOW, INTERNET, FOREGROUND_SERVICE,
        FOREGROUND_SERVICE_SPECIAL_USE, and POST_NOTIFICATIONS permissions."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)

        assert "SYSTEM_ALERT_WINDOW" in result
        assert "INTERNET" in result
        assert "FOREGROUND_SERVICE" in result
        assert "FOREGROUND_SERVICE_SPECIAL_USE" in result
        assert "POST_NOTIFICATIONS" in result

    def test_does_not_duplicate_existing_permissions(self, sample_apk_dir):
        """Should not duplicate INTERNET permission since it's already in manifest."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)

        # INTERNET should appear exactly once as a permission element
        count = result.count("android.permission.INTERNET")
        assert count == 1, f"INTERNET permission duplicated ({count} occurrences)"

    def test_adds_benchify_service(self, sample_apk_dir):
        """Should register BenchifyService inside <application> block."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)

        assert "dev.benchify.BenchifyService" in result
        assert "android:foregroundServiceType" in result
        assert 'android:exported="false"' in result

    def test_adds_benchify_broadcast_receiver(self, sample_apk_dir):
        """Should register BenchifyBroadcastReceiver with intent filter."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)

        assert "dev.benchify.BenchifyBroadcastReceiver" in result
        assert "com.benchify.COMMAND" in result
        assert "intent-filter" in result

    def test_preserves_existing_manifest_content(self, sample_apk_dir):
        """Should preserve all original manifest content."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)

        # Original content should be preserved
        assert 'package="com.example.testapp"' in result
        assert "MainActivity" in result
        assert "intent.action.MAIN" in result

    def test_handles_empty_manifest(self):
        """Should handle a minimal manifest with no permissions or application block."""
        minimal = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.minimal">
    <application
        android:allowBackup="true"
        android:label="Minimal">
    </application>
</manifest>
"""
        result = patch_manifest(minimal)
        assert "SYSTEM_ALERT_WINDOW" in result
        assert "dev.benchify.BenchifyService" in result
        assert "com.benchify.COMMAND" in result

    def test_handles_manifest_without_application_block(self):
        """Should handle manifest that has no application element (edge case)."""
        no_app = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.noapp">
</manifest>
"""
        result = patch_manifest(no_app)
        # Should add an application block
        assert "<application" in result
        assert "dev.benchify.BenchifyService" in result

    def test_manifest_patch_idempotent(self, sample_apk_dir):
        """Running patch twice should not double-add elements."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        once = patch_manifest(original)
        twice = patch_manifest(once)

        # BenchifyService should appear the same number of times
        count_once = once.count("dev.benchify.BenchifyService")
        count_twice = twice.count("dev.benchify.BenchifyService")

        assert count_once == count_twice, (
            f"Manifest patch is not idempotent: {count_once} vs {count_twice}"
        )

    def test_result_is_valid_xml(self, sample_apk_dir):
        """The patched manifest should be parseable as valid XML."""
        from lxml import etree

        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)

        # Should not raise an exception
        try:
            root = etree.fromstring(result.encode("utf-8"))
            assert root.tag == "manifest"
        except etree.XMLSyntaxError as e:
            pytest.fail(f"Patched manifest is not valid XML: {e}")

    def test_result_contains_required_namespace(self, sample_apk_dir):
        """The patched manifest should preserve Android namespace."""
        manifest_path = os.path.join(sample_apk_dir, "AndroidManifest.xml")

        with open(manifest_path, "r") as f:
            original = f.read()

        result = patch_manifest(original)
        assert "http://schemas.android.com/apk/res/android" in result
