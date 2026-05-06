"""Tests for verifier.py — Multi-step APK verification."""

import os
import pytest
from unittest.mock import patch, MagicMock, mock_open
from injector.verifier import (
    verify_apksigner,
    verify_smali_patch,
    verify_adb_connectivity,
)


class TestVerifyApksigner:
    """Tests for apksigner signature verification."""

    @patch("injector.verifier.subprocess.run")
    def test_returns_pass_on_success(self, mock_run, temp_dir):
        """Should return pass status when apksigner exits 0."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Verified using v1 scheme (JAR signing): true\nVerified using v2 scheme (APK Signature Scheme v2): true",
            stderr="",
        )

        result = verify_apksigner("/fake/test.apk")

        assert result["status"] == "pass"
        assert "Signature valid" in result["detail"]

    @patch("injector.verifier.subprocess.run")
    def test_detects_scheme_versions(self, mock_run, temp_dir):
        """Should detect v1, v2, v3 signature schemes from output."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Verified using v1 scheme: true\nVerified using v2 scheme: true\nVerified using v3 scheme: true",
            stderr="",
        )

        result = verify_apksigner("/fake/test.apk")

        assert "v1" in result["detail"]
        assert "v2" in result["detail"]
        assert "v3" in result["detail"]

    @patch("injector.verifier.subprocess.run")
    def test_raises_on_verify_failure(self, mock_run, temp_dir):
        """Should raise RuntimeError when apksigner exits non-zero."""
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout="",
            stderr="DOES NOT VERIFY",
        )

        with pytest.raises(RuntimeError, match="apksigner verify failed"):
            verify_apksigner("/fake/test.apk")


class TestVerifySmaliPatch:
    """Tests for Smali patch validation."""

    @patch("injector.verifier.subprocess.run")
    @patch("injector.verifier.os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_confirms_sdk_init_present(self, mock_file, mock_walk, mock_run):
        """Should return pass when SdkLoader.init is found."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        # Mock walk to return a smali file
        mock_walk.return_value = [
            ("/tmp/pb_verify/smali", [], ["MyApp.smali"]),
        ]

        # Mock the file read to contain SDK init
        mock_file.return_value.read.return_value = (
            "invoke-static {p0}, Ldev/benchify/SdkLoader;->init(Landroid/content/Context;)V"
        )

        result = verify_smali_patch("/fake/test.apk")

        assert result["status"] == "pass"
        assert "SDK init confirmed" in result["detail"]

    @patch("injector.verifier.subprocess.run")
    @patch("injector.verifier.os.walk")
    @patch("builtins.open", new_callable=mock_open)
    def test_raises_when_sdk_init_missing(self, mock_file, mock_walk, mock_run):
        """Should raise RuntimeError when SdkLoader.init is not found."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        # Mock walk but with no matching content
        mock_walk.return_value = [
            ("/tmp/pb_verify/smali", [], ["MyApp.smali"]),
        ]
        mock_file.return_value.read.return_value = "Some other smali code"

        with pytest.raises(RuntimeError, match="SDK injection not found"):
            verify_smali_patch("/fake/test.apk")


class TestVerifyAdbConnectivity:
    """Tests for ADB port forwarding and SDK connectivity test."""

    @patch("injector.verifier.socket.socket")
    @patch("injector.verifier.time.sleep")
    @patch("injector.verifier.subprocess.run")
    def test_returns_pass_on_successful_connect(self, mock_run, mock_sleep, mock_socket):
        """Should connect to port 8080, read JSON, and verify timestamp field."""
        # Mock ADB commands
        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="Events injected: 1", stderr=""),
            MagicMock(returncode=0, stdout="8080", stderr=""),
            MagicMock(returncode=0, stdout="", stderr=""),
        ]

        # Mock socket connection
        mock_sock = MagicMock()
        mock_socket.return_value = mock_sock

        # Simulate receiving JSON data
        def mock_recv(size):
            mock_recv.call_count = getattr(mock_recv, "call_count", 0) + 1
            if mock_recv.call_count == 1:
                return b'{"timestamp": 1700000000000, "fps": 60}\n'
            return b""

        mock_recv.call_count = 0
        mock_sock.recv = mock_recv

        result = verify_adb_connectivity("emulator-5554", "com.example.app")

        assert result["status"] == "pass"
        assert "SDK responding" in result["detail"]

    @patch("injector.verifier.socket.socket")
    @patch("injector.verifier.time.sleep")
    @patch("injector.verifier.subprocess.run")
    def test_handles_connection_timeout(self, mock_run, mock_sleep, mock_socket):
        """Should raise RuntimeError on socket timeout."""
        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="Events injected: 1", stderr=""),
            MagicMock(returncode=0, stdout="8080", stderr=""),
            MagicMock(returncode=0, stdout="", stderr=""),  # cleanup
        ]
        mock_sleep.return_value = None

        import socket as socket_module
        mock_sock = MagicMock()
        mock_sock.connect.side_effect = socket_module.timeout("Timed out")
        mock_socket.return_value = mock_sock

        with pytest.raises(RuntimeError, match="Cannot connect"):
            verify_adb_connectivity("emulator-5554", "com.example.app")
