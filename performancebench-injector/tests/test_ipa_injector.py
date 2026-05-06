"""Tests for ipa_injector.py — iOS IPA dylib injection orchestrator.

Per 05-02-PLAN Task 1: Test inject_dylib(), FairPlay encryption check,
Info.plist patching, IPA repack, and signing orchestration.
"""
import os
import pytest
import zipfile
import tempfile
import shutil
import plistlib
from unittest.mock import patch, MagicMock, mock_open
from injector.ipa_injector import (
    InjectionResult,
    check_fairplay_encryption,
    extract_ipa,
    patch_info_plist,
    embed_framework,
    repack_ipa,
    inject_dylib,
)


class TestFairPlayCheck:
    """Tests for FairPlay DRM encryption detection (cryptid check)."""

    def test_unencrypted_when_cryptid_zero(self):
        """Mach-O with cryptid=0 should pass encryption check."""
        # Simulate a Mach-O header with LC_ENCRYPTION_INFO containing cryptid=0
        # We test the logical check — real Mach-O parsing uses macholib/subprocess
        assert check_fairplay_encryption(cryptid=0) == True
        assert check_fairplay_encryption(cryptid=None) == True

    def test_encrypted_raises_when_cryptid_nonzero(self):
        """Mach-O with cryptid!=0 should raise an error."""
        with pytest.raises(RuntimeError, match="encrypted.*FairPlay"):
            check_fairplay_encryption(cryptid=1)

    def test_encrypted_raises_when_cryptid_two(self):
        """Mach-O with cryptid=2 should also raise."""
        with pytest.raises(RuntimeError, match="encrypted.*FairPlay"):
            check_fairplay_encryption(cryptid=2)


class TestExtractIpa:
    """Tests for IPA extraction (unzipping)."""

    def test_extract_creates_payload_dir(self, temp_dir):
        """Extract should unzip IPA into temp dir with Payload/."""
        # Create a minimal IPA zip
        ipa_path = os.path.join(temp_dir, "test.ipa")
        payload_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        os.makedirs(payload_dir, exist_ok=True)
        # Write a dummy Info.plist
        info_plist = {"CFBundleIdentifier": "com.test.app"}
        with open(os.path.join(payload_dir, "Info.plist"), "wb") as f:
            plistlib.dump(info_plist, f)
        # Create the zip
        original_cwd = os.getcwd()
        os.chdir(temp_dir)
        with zipfile.ZipFile(ipa_path, "w") as zf:
            for root, dirs, files in os.walk("Payload"):
                for file in files:
                    full_path = os.path.join(root, file)
                    arcname = os.path.relpath(full_path, temp_dir)
                    zf.write(full_path, arcname)
        os.chdir(original_cwd)

        # Extract
        extract_dir = os.path.join(temp_dir, "extracted")
        result = extract_ipa(ipa_path, extract_dir)

        assert os.path.isdir(result)
        assert os.path.isdir(os.path.join(result, "Payload"))
        assert os.path.isdir(os.path.join(result, "Payload", "TestApp.app"))

    def test_extract_invalid_ipa_raises(self, temp_dir):
        """Non-zip file should raise an error."""
        bad_path = os.path.join(temp_dir, "not-an-ipa.ipa")
        with open(bad_path, "w") as f:
            f.write("not a zip file")
        with pytest.raises(RuntimeError, match="not a valid IPA"):
            extract_ipa(bad_path, os.path.join(temp_dir, "extracted"))


class TestPatchInfoPlist:
    """Tests for Info.plist patching."""

    def test_patches_minimum_os_version(self, temp_dir):
        """Should set MinimumOSVersion to 14.0 if lower."""
        info_plist = {
            "CFBundleIdentifier": "com.test.app",
            "CFBundleDisplayName": "Test App",
            "MinimumOSVersion": "11.0",
            "UIDeviceFamily": [1],
        }
        result = patch_info_plist(info_plist)
        assert result["MinimumOSVersion"] == "14.0"

    def test_keeps_higher_os_version(self, temp_dir):
        """Should keep OS version if already >= 14.0."""
        info_plist = {
            "CFBundleIdentifier": "com.test.app",
            "MinimumOSVersion": "15.0",
        }
        result = patch_info_plist(info_plist)
        assert result["MinimumOSVersion"] == "15.0"

    def test_adds_uid_device_family(self, temp_dir):
        """Should ensure UIDeviceFamily includes 1."""
        info_plist = {
            "CFBundleIdentifier": "com.test.app",
            "UIDeviceFamily": [2],
        }
        result = patch_info_plist(info_plist)
        assert 1 in result["UIDeviceFamily"]

    def test_no_network_descriptions_added(self, temp_dir):
        """Should NOT add network usage descriptions (privacy contract)."""
        info_plist = {"CFBundleIdentifier": "com.test.app"}
        result = patch_info_plist(info_plist)
        assert "NSAppTransportSecurity" not in result
        assert "NSLocalNetworkUsageDescription" not in result


class TestEmbedFramework:
    """Tests for embedding PerformanceBench.framework into .app bundle."""

    def test_creates_frameworks_directory(self, temp_dir):
        """Should create Frameworks/ dir in .app bundle."""
        app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        os.makedirs(app_dir, exist_ok=True)
        # Create a fake framework to copy
        framework_dir = os.path.join(temp_dir, "PerformanceBench.framework")
        os.makedirs(framework_dir, exist_ok=True)
        with open(os.path.join(framework_dir, "PerformanceBench"), "wb") as f:
            f.write(b"dylib")

        result = embed_framework(app_dir, framework_dir)

        assert result is True
        frameworks = os.path.join(app_dir, "Frameworks", "PerformanceBench.framework", "PerformanceBench")
        assert os.path.isfile(frameworks)


class TestRepackIpa:
    """Tests for IPA repacking (re-zipping)."""

    def test_repack_creates_valid_zip(self, temp_dir):
        """Should create a valid zip IPA from Payload directory."""
        # Create a Payload structure
        app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        os.makedirs(app_dir, exist_ok=True)
        with open(os.path.join(app_dir, "TestApp"), "wb") as f:
            f.write(b"binary")
        info_plist = {"CFBundleIdentifier": "com.test.app"}
        with open(os.path.join(app_dir, "Info.plist"), "wb") as f:
            plistlib.dump(info_plist, f)

        output_path = os.path.join(temp_dir, "output.ipa")
        payload_dir = os.path.join(temp_dir, "Payload")
        result = repack_ipa(payload_dir, output_path)

        assert result == output_path
        assert os.path.isfile(output_path)
        # Verify it's a valid zip
        assert zipfile.is_zipfile(output_path)


class TestInjectionResult:
    """Tests for InjectionResult dataclass."""

    def test_success_result(self):
        """Success result should have success=True."""
        result = InjectionResult(
            success=True,
            output_path="/tmp/out.ipa",
            signing_method_used="free_apple_id",
            warnings=[],
            steps_completed=7,
        )
        assert result.success is True
        assert result.output_path == "/tmp/out.ipa"
        assert result.signing_method_used == "free_apple_id"

    def test_failure_result(self):
        """Failure result should have success=False with error."""
        result = InjectionResult(
            success=False,
            output_path="",
            signing_method_used="",
            warnings=["Encrypted IPA"],
            steps_completed=1,
            error="FairPlay DRM detected",
        )
        assert result.success is False
        assert result.error == "FairPlay DRM detected"
