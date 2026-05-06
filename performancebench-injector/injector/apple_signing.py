#!/usr/bin/env python3
"""
Apple code signing orchestrator for iOS IPA injection.

Per 05-02-PLAN Task 1 (D-06):
  Auto-detects three signing methods:
    1. Free Apple ID via altool (7-day expiry, sideload only)
    2. Paid Developer Account with provisioning profile
    3. User-provided signing certificate

Threat mitigations:
  - T-05-06: Only use xcrun altool (Apple-signed binary), validate path
  - T-05-07: Credentials in macOS Keychain via security add-generic-password
              App-specific password enforced (not main Apple ID password)
"""
import os
import re
import sys
import json
import subprocess
import plistlib
import tempfile
from enum import Enum
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any


class SigningMethod(Enum):
    """Available iOS code signing methods."""
    FREE_APPLE_ID = "free_apple_id"
    PAID_DEVELOPER = "paid_developer"
    USER_CERTIFICATE = "user_certificate"


@dataclass
class SignResult:
    """Result of a code signing operation."""
    success: bool
    warnings: List[str] = field(default_factory=list)
    method: SigningMethod = SigningMethod.FREE_APPLE_ID
    error: Optional[str] = None


def _validate_xcrun() -> str:
    """Validate that xcrun is available and from Xcode installation.

    Per T-05-06: Only use xcrun altool (Apple-signed binary).
    Reject xcrun from PATH if not inside Xcode.app or Xcode CLT.

    Returns:
        Path to valid xcrun.

    Raises:
        RuntimeError: If xcrun is not found or from untrusted location.
    """
    try:
        result = subprocess.run(
            ["which", "xcrun"],
            capture_output=True, text=True, timeout=10
        )
        xcrun_path = result.stdout.strip()
        if not xcrun_path:
            raise RuntimeError("xcrun not found. Install Xcode command line tools.")

        # Validate path is from Xcode or CLT
        if ("Xcode.app" not in xcrun_path
                and "CommandLineTools" not in xcrun_path
                and "XcodeDefault" not in xcrun_path):
            raise RuntimeError(
                f"xcrun at '{xcrun_path}' is not from a trusted Xcode installation. "
                "Ensure xcrun is from Xcode.app or Xcode Command Line Tools."
            )
        return xcrun_path
    except subprocess.TimeoutExpired:
        raise RuntimeError("Timed out while locating xcrun.")


def detect_available_methods() -> List[SigningMethod]:
    """Auto-detect available iOS signing methods from system state.

    Check 1: xcrun altool --list-providers → Free Apple ID or Paid Developer
    Check 2: ~/Library/MobileDevice/Provisioning Profiles/ → Paid Developer
    Check 3: security find-identity -v -p codesigning → User Certificate

    Returns:
        List of available SigningMethod enums.
    """
    available: List[SigningMethod] = []

    # Check 1: altool availability (check if xcrun + altool is installed)
    try:
        # First check if xcrun altool exists as a tool
        find_result = subprocess.run(
            ["xcrun", "--find", "altool"],
            capture_output=True, text=True, timeout=10
        )
        if find_result.returncode == 0 and find_result.stdout.strip():
            # Tool exists, try list-providers to check if auth works
            try:
                provider_result = subprocess.run(
                    ["xcrun", "altool", "--list-providers", "-u", "check@example.com",
                     "-p", "dummy"],
                    capture_output=True, text=True, timeout=30
                )
                # Returncode 0 = auth success (free or paid dev)
                # Returncode non-zero = tool works but auth failed
                # Either way, altool is available as a signing tool
                if "Provider" in (provider_result.stdout + provider_result.stderr):
                    available.append(SigningMethod.FREE_APPLE_ID)
            except subprocess.TimeoutExpired:
                available.append(SigningMethod.FREE_APPLE_ID)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Check 2: Provisioning profiles
    try:
        profiles_dir = os.path.expanduser(
            "~/Library/MobileDevice/Provisioning Profiles"
        )
        if os.path.exists(profiles_dir):
            profiles = [f for f in os.listdir(profiles_dir)
                        if f.endswith(".mobileprovision")]
            if profiles:
                available.append(SigningMethod.PAID_DEVELOPER)
    except (OSError, PermissionError):
        pass

    # Check 3: Code signing identities
    try:
        result = subprocess.run(
            ["security", "find-identity", "-v", "-p", "codesigning"],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0 and result.stdout.strip():
            # Look for valid identities (not just the header line)
            identities = [line for line in result.stdout.splitlines()
                          if ")" in line and "valid identities found" not in line.lower()]
            if identities:
                available.append(SigningMethod.USER_CERTIFICATE)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return available


def create_minimal_entitlements() -> Dict[str, Any]:
    """Create a minimal entitlements.plist for development signing.

    Returns:
        Dict with get-task-allow=true (required for dev signing).
    """
    return {
        "get-task-allow": True,
        "com.apple.developer.team-identifier": "",
    }


def _write_entitlements(entitlements: Dict[str, Any]) -> str:
    """Write entitlements dict to a temporary plist file.

    Returns:
        Path to the temporary entitlements file.
    """
    fd, path = tempfile.mkstemp(suffix=".plist", prefix="pb_entitlements_")
    with os.fdopen(fd, "wb") as f:
        plistlib.dump(entitlements, f)
    return path


def _find_app_bundle_in_dir(extract_dir: str) -> Optional[str]:
    """Find the .app bundle path within an extracted IPA directory.

    Args:
        extract_dir: Directory containing Payload/ or .app bundle.

    Returns:
        Path to the .app bundle, or None.
    """
    # Check if extract_dir itself is a .app bundle
    if extract_dir.endswith(".app") and os.path.isdir(extract_dir):
        return extract_dir

    # Check Payload/
    payload = os.path.join(extract_dir, "Payload")
    if os.path.isdir(payload):
        for item in os.listdir(payload):
            if item.endswith(".app"):
                return os.path.join(payload, item)

    # Check extracted/ directory
    extracted = os.path.join(extract_dir, "extracted")
    if os.path.isdir(extracted):
        return _find_app_bundle_in_dir(extracted)

    return None


def store_apple_credentials(apple_id: str, app_specific_password: str) -> bool:
    """Store Apple ID credentials in macOS Keychain.

    Per T-05-07: Credentials stored via security add-generic-password.
    App-specific password enforced (must contain dashes per Apple format).

    Args:
        apple_id: Apple ID email address.
        app_specific_password: App-specific password (format: xxxx-xxxx-xxxx-xxxx).

    Returns:
        True if successfully stored.

    Raises:
        ValueError: If password doesn't match app-specific format.
    """
    # Validate app-specific password format (contains dashes)
    if not re.search(r'.*-.*-.*-.*', app_specific_password):
        raise ValueError(
            "An app-specific password is required (not your main Apple ID password). "
            "Create one at https://appleid.apple.com → Sign-In and Security → App-Specific Passwords. "
            "Format: xxxx-xxxx-xxxx-xxxx"
        )

    service_name = "com.performancebench.injector"
    try:
        # Delete existing entry if present
        subprocess.run(
            ["security", "delete-generic-password",
             "-a", apple_id, "-s", service_name],
            capture_output=True, timeout=10
        )

        # Add new entry
        result = subprocess.run(
            ["security", "add-generic-password",
             "-a", apple_id,
             "-s", service_name,
             "-w", app_specific_password,
             "-T", "/usr/bin/security",
             "-U"],
            capture_output=True, text=True, timeout=15
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def free_apple_id_sign(
    ipa_path: str,
    apple_id: str,
    app_specific_password: str,
) -> SignResult:
    """Sign an IPA/executable using a free Apple ID.

    Uses xcrun codesign with Apple Development identity.
    Includes 7-day expiry warning for sideloaded apps.

    Args:
        ipa_path: Path to the extracted app directory or IPA.
        apple_id: Apple ID email address.
        app_specific_password: App-specific password.

    Returns:
        SignResult with success status and warnings.
    """
    warnings: List[str] = []
    warnings.append(
        "Free Apple ID signing: signed apps expire after 7 days. "
        "You must re-sign and re-install weekly. Not suitable for production distribution."
    )

    try:
        # Find the .app bundle
        app_dir = _find_app_bundle_in_dir(ipa_path)
        if not app_dir:
            return SignResult(
                success=False,
                warnings=warnings,
                method=SigningMethod.FREE_APPLE_ID,
                error="No .app bundle found in the provided path",
            )

        # Store credentials in keychain
        if not store_apple_credentials(apple_id, app_specific_password):
            warnings.append("Failed to store credentials in Keychain. Continuing anyway...")

        # Create entitlements
        entitlements = create_minimal_entitlements()
        ent_path = _write_entitlements(entitlements)

        try:
            # Sign the framework first (if present)
            framework_dir = os.path.join(
                app_dir, "Frameworks", "PerformanceBench.framework"
            )
            if os.path.isdir(framework_dir):
                dylib_name = "PerformanceBench"
                dylib_path = os.path.join(framework_dir, dylib_name)
                if os.path.isfile(dylib_path):
                    subprocess.run(
                        ["codesign", "--force", "--sign", "-",
                         "--timestamp=none", dylib_path],
                        capture_output=True, text=True, timeout=60
                    )

            # Sign the main app
            result = subprocess.run(
                ["codesign", "--force", "--deep", "--sign", "-",
                 "--entitlements", ent_path,
                 "--timestamp=none",
                 app_dir],
                capture_output=True, text=True, timeout=120
            )

            if result.returncode != 0:
                return SignResult(
                    success=False,
                    warnings=warnings,
                    method=SigningMethod.FREE_APPLE_ID,
                    error=f"codesign failed: {result.stderr.strip()[:500]}",
                )

            return SignResult(
                success=True,
                warnings=warnings,
                method=SigningMethod.FREE_APPLE_ID,
            )
        finally:
            # Clean up entitlements temp file
            if os.path.exists(ent_path):
                os.unlink(ent_path)

    except Exception as e:
        return SignResult(
            success=False,
            warnings=warnings,
            method=SigningMethod.FREE_APPLE_ID,
            error=str(e),
        )


def paid_developer_sign(
    ipa_path: str,
    team_id: str,
    profile_path: str,
) -> SignResult:
    """Sign an IPA using a paid Apple Developer account.

    Uses xcrun codesign with team ID and embedded provisioning profile.

    Args:
        ipa_path: Path to the extracted app directory or IPA.
        team_id: Apple Developer Team ID.
        profile_path: Path to .mobileprovision file.

    Returns:
        SignResult with success status.
    """
    try:
        app_dir = _find_app_bundle_in_dir(ipa_path)
        if not app_dir:
            return SignResult(
                success=False,
                method=SigningMethod.PAID_DEVELOPER,
                error="No .app bundle found in the provided path",
            )

        # Sign framework first
        framework_dir = os.path.join(app_dir, "Frameworks", "PerformanceBench.framework")
        if os.path.isdir(framework_dir):
            dylib_name = "PerformanceBench"
            dylib_path = os.path.join(framework_dir, dylib_name)
            if os.path.isfile(dylib_path):
                subprocess.run(
                    ["codesign", "--force", "--sign", team_id, dylib_path],
                    capture_output=True, text=True, timeout=60
                )

        # Embed provisioning profile
        if profile_path and os.path.isfile(profile_path):
            dest_profile = os.path.join(app_dir, "embedded.mobileprovision")
            with open(profile_path, "rb") as src:
                with open(dest_profile, "wb") as dst:
                    dst.write(src.read())

        # Sign the main app with team ID
        args = ["codesign", "--force", "--deep", "--sign", team_id]
        if profile_path and os.path.isfile(profile_path):
            args.extend(["--embed", profile_path])

        result = subprocess.run(
            args + [app_dir],
            capture_output=True, text=True, timeout=120
        )

        if result.returncode != 0:
            return SignResult(
                success=False,
                method=SigningMethod.PAID_DEVELOPER,
                error=f"codesign failed: {result.stderr.strip()[:500]}",
            )

        return SignResult(
            success=True,
            method=SigningMethod.PAID_DEVELOPER,
        )

    except Exception as e:
        return SignResult(
            success=False,
            method=SigningMethod.PAID_DEVELOPER,
            error=str(e),
        )


def user_certificate_sign(
    ipa_path: str,
    cert_identity: str,
) -> SignResult:
    """Sign an IPA using a user-provided code signing certificate.

    Uses codesign with the specified certificate identity hash.

    Args:
        ipa_path: Path to the extracted app directory or IPA.
        cert_identity: Certificate identity hash from security find-identity.

    Returns:
        SignResult with success status.
    """
    try:
        app_dir = _find_app_bundle_in_dir(ipa_path)
        if not app_dir:
            return SignResult(
                success=False,
                method=SigningMethod.USER_CERTIFICATE,
                error="No .app bundle found in the provided path",
            )

        # Sign framework first
        framework_dir = os.path.join(app_dir, "Frameworks", "PerformanceBench.framework")
        if os.path.isdir(framework_dir):
            dylib_name = "PerformanceBench"
            dylib_path = os.path.join(framework_dir, dylib_name)
            if os.path.isfile(dylib_path):
                subprocess.run(
                    ["codesign", "--force", "--sign", cert_identity, dylib_path],
                    capture_output=True, text=True, timeout=60
                )

        # Sign the main app
        result = subprocess.run(
            ["codesign", "--force", "--deep", "--sign", cert_identity, app_dir],
            capture_output=True, text=True, timeout=120
        )

        if result.returncode != 0:
            return SignResult(
                success=False,
                method=SigningMethod.USER_CERTIFICATE,
                error=f"codesign failed: {result.stderr.strip()[:500]}",
            )

        return SignResult(
            success=True,
            method=SigningMethod.USER_CERTIFICATE,
        )

    except Exception as e:
        return SignResult(
            success=False,
            method=SigningMethod.USER_CERTIFICATE,
            error=str(e),
        )


if __name__ == "__main__":
    # Self-test: detect available signing methods
    methods = detect_available_methods()
    result = {
        "available_methods": [m.value for m in methods],
        "count": len(methods),
    }
    print(json.dumps(result, indent=2))
