"""Tests for apk_decompiler.py — APK decompilation via apktool."""

import os
import zipfile
import pytest
from unittest.mock import patch, MagicMock
from injector.apk_decompiler import (
    validate_apk,
    decompile_apk,
    DecompileResult,
    ApkValidationError,
)


def _create_fake_apk(dir_path, filename="test.apk"):
    """Helper: create a minimal valid ZIP file at dir_path/filename."""
    apk_path = os.path.join(dir_path, filename)
    with zipfile.ZipFile(apk_path, "w") as zf:
        zf.writestr("AndroidManifest.xml", "<manifest></manifest>")
    return apk_path


class TestValidateApk:
    """Tests for APK input validation."""

    def test_validates_apk_magic_bytes(self, temp_dir):
        """Should accept a valid APK (ZIP file with PK header)."""
        apk_path = _create_fake_apk(temp_dir, "test.apk")
        result = validate_apk(apk_path)
        assert result is True

    def test_rejects_non_zip_file(self, temp_dir):
        """Should reject a file that is not a valid ZIP/APK."""
        not_apk = os.path.join(temp_dir, "not_apk.txt")
        with open(not_apk, "w") as f:
            f.write("This is not an APK file")

        with pytest.raises(ApkValidationError, match="valid APK"):
            validate_apk(not_apk)

    def test_rejects_nonexistent_file(self):
        """Should reject a path that doesn't exist."""
        with pytest.raises(ApkValidationError):
            validate_apk("/nonexistent/path/test.apk")

    def test_detects_zip_without_classes_dex(self, temp_dir):
        """Should still validate a ZIP without classes.dex (it's an APK structure)."""
        apk_path = os.path.join(temp_dir, "minimal.apk")
        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("resources.arsc", "fake")
            zf.writestr("AndroidManifest.xml", "<manifest></manifest>")

        result = validate_apk(apk_path)
        assert result is True


class TestDecompileApk:
    """Tests for APK decompilation via apktool."""

    @patch("injector.apk_decompiler.subprocess.run")
    def test_calls_apktool_with_correct_args(self, mock_run, temp_dir):
        """Should call apktool with -f -s flags and correct output directory."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        apk_path = _create_fake_apk(temp_dir, "input.apk")
        out_dir = os.path.join(temp_dir, "decoded")

        decompile_apk(apk_path, out_dir)

        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert "apktool" in args
        assert "d" in args
        assert "-f" in args
        assert "-s" in args
        assert apk_path in args

    @patch("injector.apk_decompiler.subprocess.run")
    def test_returns_decompile_result_on_success(self, mock_run, temp_dir):
        """Should return DecompileResult with output directory on success."""
        mock_run.return_value = MagicMock(returncode=0, stdout="I: Done", stderr="")

        apk_path = _create_fake_apk(temp_dir, "input.apk")
        out_dir = os.path.join(temp_dir, "decoded")

        result = decompile_apk(apk_path, out_dir)

        assert isinstance(result, DecompileResult)
        assert result.success is True
        assert result.output_dir == out_dir

    @patch("injector.apk_decompiler.subprocess.run")
    def test_raises_on_apktool_failure(self, mock_run, temp_dir):
        """Should raise RuntimeError when apktool fails."""
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="apktool: error: something went wrong",
        )

        apk_path = _create_fake_apk(temp_dir, "input.apk")
        out_dir = os.path.join(temp_dir, "decoded")

        with pytest.raises(RuntimeError, match="apktool"):
            decompile_apk(apk_path, out_dir)
