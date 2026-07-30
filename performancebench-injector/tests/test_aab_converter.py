"""Tests for aab_converter.py — Android App Bundle (AAB) conversion."""

import os
import zipfile
import pytest
from unittest.mock import patch, MagicMock
from injector.aab_converter import convert_aab_to_apk, AabConversionError


def _create_fake_aab(dir_path, filename="app.aab"):
    """Helper: create a minimal valid ZIP file (AAB is a ZIP)."""
    aab_path = os.path.join(dir_path, filename)
    with zipfile.ZipFile(aab_path, "w") as zf:
        zf.writestr("BundleConfig.pb", "fake")
    return aab_path


class TestConvertAabToApk:
    """Tests for AAB to universal APK conversion via bundletool."""

    @patch("injector.aab_converter.subprocess.run")
    def test_calls_bundletool_with_correct_args(self, mock_run, temp_dir):
        """Should invoke bundletool with build-apks --mode=universal."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        aab_path = _create_fake_aab(temp_dir, "app.aab")
        output_dir = os.path.join(temp_dir, "output")
        os.makedirs(output_dir, exist_ok=True)

        # This will fail on the .apks extraction step (mock returns no APK file)
        # since we only mock subprocess.run, not file creation.
        # But the assertion we care about is the subprocess call args.
        try:
            convert_aab_to_apk(aab_path, output_dir)
        except (AabConversionError, Exception):
            pass  # Expected — we don't have a real .apks to extract

        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        # Check for key bundletool arguments
        cmd_str = " ".join(str(a) for a in args)
        assert "build-apks" in cmd_str
        assert "universal" in cmd_str
        assert "bundletool" in cmd_str

    @patch("injector.aab_converter.subprocess.run")
    def test_signing_passwords_use_env_vars(self, mock_run, temp_dir):
        """B-095: passwords MUST go via env:VAR, not pass: CLI literals."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        aab_path = _create_fake_aab(temp_dir, "app.aab")
        output_dir = os.path.join(temp_dir, "output")
        os.makedirs(output_dir, exist_ok=True)
        ks_path = os.path.join(temp_dir, "test.keystore")
        with open(ks_path, "w") as f:
            f.write("fake keystore")

        try:
            convert_aab_to_apk(
                aab_path,
                output_dir,
                keystore_path=ks_path,
                keystore_password="secret-ks",
                key_alias="mykey",
                key_password="secret-key",
            )
        except (AabConversionError, Exception):
            pass  # Expected — no real .apks to extract

        mock_run.assert_called_once()
        call_kwargs = mock_run.call_args.kwargs
        args = mock_run.call_args[0][0]
        joined = " ".join(str(a) for a in args)

        assert "pass:secret-ks" not in joined
        assert "pass:secret-key" not in joined
        assert "env:PB_KS_PASS" in joined
        assert "env:PB_KEY_PASS" in joined

        env = call_kwargs.get("env") or {}
        assert env.get("PB_KS_PASS") == "secret-ks"
        assert env.get("PB_KEY_PASS") == "secret-key"

    @patch("injector.aab_converter.subprocess.run")
    def test_raises_on_bundletool_failure(self, mock_run, temp_dir):
        """Should raise AabConversionError when bundletool fails."""
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="bundletool: error",
        )

        aab_path = _create_fake_aab(temp_dir, "app.aab")
        output_dir = os.path.join(temp_dir, "output")

        with pytest.raises(AabConversionError):
            convert_aab_to_apk(aab_path, output_dir)

    def test_rejects_nonexistent_aab_file(self, temp_dir):
        """Should raise AabConversionError for missing AAB file."""
        output_dir = os.path.join(temp_dir, "output")
        os.makedirs(output_dir, exist_ok=True)

        with pytest.raises(AabConversionError, match="not found"):
            convert_aab_to_apk(
                os.path.join(temp_dir, "nonexistent.aab"), output_dir
            )
