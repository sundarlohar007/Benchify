"""Tests for ipa_verifier.py — Post-injection IPA verification.

Per 05-02-PLAN Task 1: Test verify_injection() checks for valid IPA structure,
PerformanceBench.framework presence, LC_LOAD_DYLIB in load commands,
valid code signature, and deep verification.
"""
import os
import pytest
import zipfile
import tempfile
from unittest.mock import patch, MagicMock
from injector.ipa_verifier import (
    CheckResult,
    VerificationResult,
    verify_ipa_structure,
    verify_framework_present,
    verify_load_command,
    verify_code_signature,
    verify_injection,
)


class TestCheckResult:
    """Tests for CheckResult dataclass."""

    def test_pass_result(self):
        result = CheckResult(name="Test", passed=True, detail="OK")
        assert result.passed is True

    def test_fail_result(self):
        result = CheckResult(name="Test", passed=False, detail="Error: not found")
        assert result.passed is False


class TestVerificationResult:
    """Tests for VerificationResult dataclass."""

    def test_all_passed(self):
        checks = [
            CheckResult("A", True, ""),
            CheckResult("B", True, ""),
        ]
        result = VerificationResult(checks=checks)
        assert result.all_passed is True

    def test_some_failed(self):
        checks = [
            CheckResult("A", True, ""),
            CheckResult("B", False, "failed"),
        ]
        result = VerificationResult(checks=checks)
        assert result.all_passed is False

    def test_empty_checks(self):
        result = VerificationResult(checks=[])
        assert result.all_passed is True


class TestVerifyIpaStructure:
    """Tests for IPA structure validation."""

    def test_valid_ipa_structure(self, temp_dir):
        """Should pass when Payload/ directory exists with .app bundle."""
        # Create a valid IPA zip with Payload/TestApp.app/
        ipa_path = os.path.join(temp_dir, "valid.ipa")
        payload_app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        os.makedirs(payload_app_dir, exist_ok=True)
        with open(os.path.join(payload_app_dir, "Info.plist"), "w") as f:
            f.write("plist")

        # Build zip with full paths (avoid chdir for cross-drive Windows compat)
        payload_parent = os.path.join(temp_dir, "Payload")
        with zipfile.ZipFile(ipa_path, "w") as zf:
            for root, dirs, files in os.walk(payload_parent):
                for file in files:
                    fp = os.path.join(root, file)
                    arcname = os.path.relpath(fp, temp_dir)
                    zf.write(fp, arcname)

        result = verify_ipa_structure(ipa_path)
        assert result.passed is True

    def test_invalid_ipa_missing_payload(self, temp_dir):
        """Should fail when Payload/ directory is missing."""
        ipa_path = os.path.join(temp_dir, "bad.ipa")
        original_cwd = os.getcwd()
        os.chdir(temp_dir)
        os.makedirs("OtherDir", exist_ok=True)
        with open(os.path.join("OtherDir", "file"), "w") as f:
            f.write("data")
        with zipfile.ZipFile(ipa_path, "w") as zf:
            zf.write("OtherDir/file", "OtherDir/file")
        os.chdir(original_cwd)

        result = verify_ipa_structure(ipa_path)
        assert result.passed is False

    def test_invalid_not_a_zip(self, temp_dir):
        """Should fail when file is not a valid zip."""
        ipa_path = os.path.join(temp_dir, "not-zip.ipa")
        with open(ipa_path, "w") as f:
            f.write("not a zip")

        result = verify_ipa_structure(ipa_path)
        assert result.passed is False


class TestVerifyFrameworkPresent:
    """Tests for PerformanceBench.framework presence check."""

    def test_framework_found(self, temp_dir):
        """Should pass when PerformanceBench.framework exists in .app."""
        app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        frameworks_dir = os.path.join(app_dir, "Frameworks", "PerformanceBench.framework")
        os.makedirs(frameworks_dir, exist_ok=True)
        with open(os.path.join(frameworks_dir, "PerformanceBench"), "wb") as f:
            f.write(b"dylib body")
        with open(os.path.join(frameworks_dir, "Info.plist"), "w") as f:
            f.write("plist")

        result = verify_framework_present(app_dir)
        assert result.passed is True

    def test_framework_missing(self, temp_dir):
        """Should fail when PerformanceBench.framework is missing."""
        app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        os.makedirs(app_dir, exist_ok=True)

        result = verify_framework_present(app_dir)
        assert result.passed is False
        assert "not found" in result.detail.lower()

    def test_dylib_missing_inside_framework(self, temp_dir):
        """Should fail when framework dir exists but dylib binary is missing."""
        app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        frameworks_dir = os.path.join(app_dir, "Frameworks", "PerformanceBench.framework")
        os.makedirs(frameworks_dir, exist_ok=True)

        result = verify_framework_present(app_dir)
        assert result.passed is False


class TestVerifyLoadCommand:
    """Tests for LC_LOAD_DYLIB load command check."""

    @patch("injector.ipa_verifier.os.path.isfile")
    @patch("injector.ipa_verifier.subprocess.run")
    def test_load_command_found(self, mock_run, mock_isfile):
        """Should pass when otool shows PerformanceBench in load commands."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="\t@executable_path/Frameworks/PerformanceBench.framework/PerformanceBench (compatibility version 1.0.0, current version 1.0.0)",
            stderr="",
        )
        mock_isfile.return_value = True

        result = verify_load_command("/fake/app")
        assert result.passed is True

    @patch("injector.ipa_verifier.os.path.isfile")
    @patch("injector.ipa_verifier.subprocess.run")
    def test_load_command_missing(self, mock_run, mock_isfile):
        """Should fail when otool does not show PerformanceBench."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="\t/System/Library/Frameworks/UIKit.framework/UIKit",
            stderr="",
        )
        mock_isfile.return_value = True

        result = verify_load_command("/fake/app")
        assert result.passed is False

    @patch("injector.ipa_verifier.os.path.isfile")
    @patch("injector.ipa_verifier.subprocess.run")
    def test_otool_not_available(self, mock_run, mock_isfile):
        """Should handle otool not found gracefully."""
        mock_run.side_effect = FileNotFoundError("otool: command not found")
        mock_isfile.return_value = True

        result = verify_load_command("/fake/app")
        assert result.passed is False
        assert "otool" in result.detail.lower()


class TestVerifyCodeSignature:
    """Tests for code signature verification."""

    @patch("injector.ipa_verifier.os.path.isdir")
    @patch("injector.ipa_verifier.subprocess.run")
    def test_signature_valid(self, mock_run, mock_isdir):
        """Should pass when codesign -dv returns valid."""
        mock_run.return_value = MagicMock(returncode=0, stdout="Signature=adcd34", stderr="")
        mock_isdir.return_value = True

        result = verify_code_signature("/fake/app")
        assert result.passed is True

    @patch("injector.ipa_verifier.os.path.isdir")
    @patch("injector.ipa_verifier.subprocess.run")
    def test_signature_invalid(self, mock_run, mock_isdir):
        """Should fail when codesign returns non-zero."""
        mock_run.return_value = MagicMock(
            returncode=1, stdout="", stderr="code object is not signed at all"
        )
        mock_isdir.return_value = True

        result = verify_code_signature("/fake/app")
        assert result.passed is False

    @patch("injector.ipa_verifier.os.path.isdir")
    @patch("injector.ipa_verifier.subprocess.run")
    def test_deep_verification_passes(self, mock_run, mock_isdir):
        """Should pass deep verification when --verify --deep --strict succeeds."""
        mock_run.return_value = MagicMock(returncode=0, stdout="valid", stderr="")
        mock_isdir.return_value = True

        result = verify_code_signature("/fake/app", deep=True)
        assert result.passed is True


class TestVerifyInjection:
    """Integration tests for the full verification pipeline."""

    @patch("injector.ipa_verifier.verify_ipa_structure")
    def test_all_checks_pass(self, mock_struct, temp_dir):
        """Should return all_passed=True when all checks pass."""
        mock_struct.return_value = CheckResult("Structure", True, "OK")

        # Create a valid IPA with framework and code signature
        ipa_path = os.path.join(temp_dir, "test.ipa")
        app_dir = os.path.join(temp_dir, "Payload", "TestApp.app")
        frameworks_dir = os.path.join(app_dir, "Frameworks", "PerformanceBench.framework")
        codesign_dir = os.path.join(app_dir, "_CodeSignature")
        os.makedirs(frameworks_dir, exist_ok=True)
        os.makedirs(codesign_dir, exist_ok=True)

        # Create dylib, app executable, and code resources
        with open(os.path.join(frameworks_dir, "PerformanceBench"), "wb") as f:
            f.write(b"dylib")
        with open(os.path.join(app_dir, "TestApp"), "wb") as f:
            f.write(b"binary")
        with open(os.path.join(codesign_dir, "CodeResources"), "w") as f:
            f.write("{}")

        # Pack into zip using full paths (avoid chdir for cross-drive Windows compat)
        payload_parent = os.path.join(temp_dir, "Payload")
        with zipfile.ZipFile(ipa_path, "w") as zf:
            for root, dirs, files in os.walk(payload_parent):
                for file in files:
                    fp = os.path.join(root, file)
                    arcname = os.path.relpath(fp, temp_dir).replace("\\", "/")
                    zf.write(fp, arcname)

        result = verify_injection(ipa_path)
        assert result.all_passed is True

    @patch("injector.ipa_verifier.verify_ipa_structure")
    def test_stops_on_structure_failure(self, mock_struct):
        """Should return failure immediately when structure check fails."""
        mock_struct.return_value = CheckResult("Structure", False, "Invalid IPA")

        result = verify_injection("/fake/test.ipa")
        assert result.all_passed is False
