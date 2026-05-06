"""Tests for resigner.py — APK re-signing via apksigner."""

import os
import pytest
from unittest.mock import patch, MagicMock
from injector.resigner import resign


class TestResign:
    """Tests for APK re-signing with apksigner."""

    @patch("injector.resigner.subprocess.run")
    def test_calls_apksigner_with_correct_args(self, mock_run, temp_dir):
        """Should invoke apksigner sign with correct keystore and password flags."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        # Create fake APK and keystore files
        apk_path = os.path.join(temp_dir, "test.apk")
        with open(apk_path, "w") as f:
            f.write("fake apk content")

        ks_path = os.path.join(temp_dir, "test.keystore")
        with open(ks_path, "w") as f:
            f.write("fake keystore")

        output = os.path.join(temp_dir, "signed.apk")

        result = resign(apk_path, ks_path, "password", "mykey", "keypass", output)

        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert "apksigner" in args
        assert "sign" in args
        assert "--ks" in args
        assert "test.keystore" in " ".join(args)
        assert "pass:password" in " ".join(args)
        assert "mykey" in " ".join(args)
        assert result == output

    @patch("injector.resigner.subprocess.run")
    def test_raises_on_apksigner_failure(self, mock_run, temp_dir):
        """Should raise RuntimeError when apksigner fails."""
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="apksigner: error: invalid keystore",
        )

        apk_path = os.path.join(temp_dir, "test.apk")
        with open(apk_path, "w") as f:
            f.write("fake apk")

        ks_path = os.path.join(temp_dir, "test.keystore")
        with open(ks_path, "w") as f:
            f.write("fake keystore")

        output = os.path.join(temp_dir, "signed.apk")

        with pytest.raises(RuntimeError, match="apksigner sign failed"):
            resign(apk_path, ks_path, "pass", "alias", "kp", output)

    def test_raises_on_missing_keystore(self, temp_dir):
        """Should raise FileNotFoundError if keystore doesn't exist."""
        apk_path = os.path.join(temp_dir, "test.apk")
        with open(apk_path, "w") as f:
            f.write("fake apk")

        with pytest.raises(FileNotFoundError, match="Keystore not found"):
            resign(apk_path, "/nonexistent/keystore.jks", "pass", "alias", "kp", "out.apk")
