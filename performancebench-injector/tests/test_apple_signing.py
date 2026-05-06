"""Tests for apple_signing.py — Apple signing method detection + execution.

Per 05-02-PLAN Task 1: Test detect_available_methods(),
free_apple_id_sign(), paid_developer_sign(), user_certificate_sign().
"""
import os
import pytest
from unittest.mock import patch, MagicMock
from injector.apple_signing import (
    SigningMethod,
    SignResult,
    detect_available_methods,
    free_apple_id_sign,
    paid_developer_sign,
    user_certificate_sign,
    create_minimal_entitlements,
    store_apple_credentials,
)


class TestSigningMethodEnum:
    """Tests for SigningMethod enum values."""

    def test_has_free_apple_id(self):
        assert SigningMethod.FREE_APPLE_ID.value == "free_apple_id"

    def test_has_paid_developer(self):
        assert SigningMethod.PAID_DEVELOPER.value == "paid_developer"

    def test_has_user_certificate(self):
        assert SigningMethod.USER_CERTIFICATE.value == "user_certificate"


class TestDetectAvailableMethods:
    """Tests for auto-detection of signing methods from system state."""

    @patch("injector.apple_signing.subprocess.run")
    def test_detects_free_apple_id(self, mock_run):
        """Should detect FREE_APPLE_ID when altool works."""
        mock_run.return_value = MagicMock(returncode=0, stdout="Provider: ...", stderr="")

        methods = detect_available_methods()
        assert SigningMethod.FREE_APPLE_ID in methods

    @patch("injector.apple_signing.subprocess.run")
    @patch("injector.apple_signing.os.path.exists")
    def test_detects_paid_developer(self, mock_exists, mock_run):
        """Should detect PAID_DEVELOPER when provisioning profiles exist."""
        # First call fails (no altool), second succeeds (prov profiles exist)
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="not found")
        mock_exists.return_value = True

        methods = detect_available_methods()
        assert SigningMethod.PAID_DEVELOPER in methods

    @patch("injector.apple_signing.subprocess.run")
    @patch("injector.apple_signing.os.path.exists")
    def test_detects_user_certificate(self, mock_exists, mock_run):
        """Should detect USER_CERTIFICATE when code-signing identities exist."""
        mock_run.side_effect = [
            MagicMock(returncode=1, stdout="", stderr=""),  # altool fails
            MagicMock(returncode=0, stdout="1) ABC123 \"iPhone Developer: Name\"", stderr=""),  # security find-identity
        ]
        mock_exists.return_value = False

        methods = detect_available_methods()
        assert SigningMethod.USER_CERTIFICATE in methods

    @patch("injector.apple_signing.subprocess.run")
    @patch("injector.apple_signing.os.path.exists")
    def test_detects_multiple_methods(self, mock_exists, mock_run):
        """Should return all available methods."""
        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="", stderr=""),  # altool succeeds
            MagicMock(returncode=0, stdout="1) ABC123 \"iPhone Developer\"", stderr=""),  # cert exists
        ]
        mock_exists.return_value = True

        methods = detect_available_methods()
        assert len(methods) >= 2
        assert SigningMethod.FREE_APPLE_ID in methods
        assert SigningMethod.USER_CERTIFICATE in methods

    @patch("injector.apple_signing.subprocess.run")
    @patch("injector.apple_signing.os.path.exists")
    def test_returns_empty_when_nothing_available(self, mock_exists, mock_run):
        """Should return empty list when no signing tools available."""
        mock_run.side_effect = [
            MagicMock(returncode=1, stdout="", stderr=""),  # altool fails
            MagicMock(returncode=1, stdout="", stderr=""),  # security fails
        ]
        mock_exists.return_value = False

        methods = detect_available_methods()
        assert len(methods) == 0


class TestFreeAppleIdSign:
    """Tests for free Apple ID code signing."""

    @patch("injector.apple_signing.subprocess.run")
    def test_signs_successfully(self, mock_run):
        """Should call altool + codesign and return success."""
        mock_run.return_value = MagicMock(returncode=0, stdout="Signed", stderr="")

        result = free_apple_id_sign(
            ipa_path="/tmp/test.ipa",
            apple_id="user@icloud.com",
            app_specific_password="abcd-efgh-ijkl-mnop",
        )

        assert result.success is True
        assert "7-day expiry" in result.warnings[0]

    @patch("injector.apple_signing.subprocess.run")
    def test_includes_seven_day_warning(self, mock_run):
        """Should include 7-day expiry warning in SignResult."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        result = free_apple_id_sign("/tmp/test.ipa", "user@icloud.com", "pass")

        assert any("7-day" in w for w in result.warnings)

    @patch("injector.apple_signing.subprocess.run")
    def test_returns_failure_on_codesign_error(self, mock_run):
        """Should return SignResult with success=False on error."""
        mock_run.return_value = MagicMock(
            returncode=1, stdout="", stderr="codesign failed"
        )

        result = free_apple_id_sign("/tmp/test.ipa", "user@icloud.com", "pass")

        assert result.success is False
        assert result.error is not None


class TestPaidDeveloperSign:
    """Tests for paid developer account code signing."""

    @patch("injector.apple_signing.subprocess.run")
    def test_signs_with_team_id_and_profile(self, mock_run):
        """Should call codesign with team_id and provisioning profile."""
        mock_run.return_value = MagicMock(returncode=0, stdout="Signed", stderr="")

        result = paid_developer_sign(
            ipa_path="/tmp/test.ipa",
            team_id="ABC123XYZ",
            profile_path="/path/to/profile.mobileprovision",
        )

        assert result.success is True
        # Verify codesign was called with correct args
        called_args = mock_run.call_args[0][0]
        assert "--sign" in called_args
        assert "ABC123XYZ" in called_args
        assert "--embed" in called_args


class TestUserCertificateSign:
    """Tests for user-provided certificate code signing."""

    @patch("injector.apple_signing.subprocess.run")
    def test_signs_with_cert_identity(self, mock_run):
        """Should call codesign with certificate identity hash."""
        mock_run.return_value = MagicMock(returncode=0, stdout="Signed", stderr="")

        result = user_certificate_sign(
            ipa_path="/tmp/test.ipa",
            cert_identity="ABC123DEF456",
        )

        assert result.success is True
        called_args = mock_run.call_args[0][0]
        assert "ABC123DEF456" in called_args


class TestCreateMinimalEntitlements:
    """Tests for entitlements.plist generation."""

    def test_creates_entitlements_with_get_task_allow(self):
        """Should create plist with get-task-allow=true."""
        plist = create_minimal_entitlements()
        assert plist["get-task-allow"] is True

    def test_is_valid_plist_format(self):
        """Should return a dict that can be serialized to plist."""
        plist = create_minimal_entitlements()
        assert isinstance(plist, dict)
        assert len(plist) > 0


class TestStoreAppleCredentials:
    """Tests for Keychain credential storage."""

    @patch("injector.apple_signing.subprocess.run")
    def test_stores_in_keychain(self, mock_run):
        """Should call security add-generic-password."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        result = store_apple_credentials(
            apple_id="user@icloud.com",
            app_specific_password="abcd-efgh-ijkl-mnop",
        )

        assert result is True
        called_args = mock_run.call_args[0][0]
        assert "add-generic-password" in called_args

    @patch("injector.apple_signing.subprocess.run")
    def test_rejects_main_password(self, mock_run):
        """Should reject non-app-specific passwords (no dashes pattern)."""
        with pytest.raises(ValueError, match="app-specific password"):
            store_apple_credentials(
                apple_id="user@icloud.com",
                app_specific_password="myMainPassword123",
            )


class TestSignResult:
    """Tests for SignResult dataclass."""

    def test_success_result(self):
        result = SignResult(
            success=True, warnings=["7-day expiry"], method=SigningMethod.FREE_APPLE_ID
        )
        assert result.success is True

    def test_failure_result(self):
        result = SignResult(
            success=False,
            warnings=[],
            method=SigningMethod.FREE_APPLE_ID,
            error="codesign failed",
        )
        assert result.success is False
        assert result.error == "codesign failed"
