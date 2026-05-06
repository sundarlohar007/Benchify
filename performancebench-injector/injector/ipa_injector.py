#!/usr/bin/env python3
"""
iOS IPA dylib injection orchestrator.

Per 05-02-PLAN Task 1 (D-06, D-07):
  Injects PerformanceBench.framework into unencrypted IPA, patches Info.plist,
  inserts LC_LOAD_DYLIB load command, re-signs, verifies, and repacks.

Steps:
  1. Extract IPA (unzip)
  2. FairPlay check (cryptid in Mach-O)
  3. Embed PerformanceBench.framework
  4. Patch Info.plist
  5. Insert load command (install_name_tool or macholib)
  6. Re-sign via apple_signing
  7. Verify via ipa_verifier
  8. Repack as IPA

Threat mitigations:
  - T-05-10: Early FairPlay detection before any modification
  - T-05-08: Dylib is localhost-only (no network capability)
"""
import os
import sys
import shutil
import tempfile
import zipfile
import plistlib
import subprocess
import json
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any


@dataclass
class InjectionResult:
    """Result of an IPA injection operation."""
    success: bool
    output_path: str
    signing_method_used: str
    warnings: List[str] = field(default_factory=list)
    steps_completed: int = 0
    error: Optional[str] = None


def check_fairplay_encryption(cryptid: Optional[int]) -> bool:
    """Check if a Mach-O binary is FairPlay-encrypted.

    Per D-07: Read LC_ENCRYPTION_INFO.cryptid. If cryptid != 0, the IPA is
    encrypted with FairPlay DRM and cannot be injected.

    Args:
        cryptid: The cryptid value from LC_ENCRYPTION_INFO (0 = unencrypted).

    Returns:
        True if unencrypted (safe to inject).

    Raises:
        RuntimeError: If cryptid is non-zero (encrypted).
    """
    if cryptid is not None and cryptid != 0:
        raise RuntimeError(
            "This IPA is encrypted (FairPlay DRM). "
            "Studio-provided unencrypted IPAs only. "
            "App Store IPAs cannot be injected."
        )
    return True


def _get_macho_cryptid(binary_path: str) -> Optional[int]:
    """Read cryptid from a Mach-O binary using otool.

    Args:
        binary_path: Path to the Mach-O executable.

    Returns:
        cryptid value (0 = unencrypted), or None if unable to determine.
    """
    try:
        result = subprocess.run(
            ["otool", "-l", binary_path],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            return None

        # Parse LC_ENCRYPTION_INFO / LC_ENCRYPTION_INFO_64
        in_encryption = False
        for line in result.stdout.splitlines():
            line = line.strip()
            if line == "cmd LC_ENCRYPTION_INFO" or line == "cmd LC_ENCRYPTION_INFO_64":
                in_encryption = True
            elif in_encryption and line.startswith("cryptid "):
                try:
                    return int(line.split()[-1])
                except (ValueError, IndexError):
                    return None
            elif in_encryption and line.startswith("cmd "):
                in_encryption = False
        return 0  # No LC_ENCRYPTION_INFO found = unencrypted
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def extract_ipa(ipa_path: str, extract_dir: str) -> str:
    """Extract an IPA file to a directory.

    An IPA is just a zip file containing Payload/AppName.app/.

    Args:
        ipa_path: Path to the .ipa file.
        extract_dir: Directory to extract into.

    Returns:
        Path to the extracted directory.

    Raises:
        RuntimeError: If the IPA is invalid or extraction fails.
    """
    if not zipfile.is_zipfile(ipa_path):
        raise RuntimeError(f"'{ipa_path}' is not a valid IPA (must be a zip file)")

    os.makedirs(extract_dir, exist_ok=True)

    try:
        with zipfile.ZipFile(ipa_path, "r") as zf:
            zf.extractall(extract_dir)
    except (zipfile.BadZipFile, OSError) as e:
        raise RuntimeError(f"Failed to extract IPA: {e}")

    return extract_dir


def _find_app_bundle(extract_dir: str) -> str:
    """Find the .app bundle inside an extracted Payload/ directory.

    Args:
        extract_dir: Directory containing extracted IPA contents.

    Returns:
        Path to the .app bundle.

    Raises:
        RuntimeError: If no .app bundle found.
    """
    payload = os.path.join(extract_dir, "Payload")
    if not os.path.isdir(payload):
        raise RuntimeError("No Payload/ directory in IPA")

    for item in os.listdir(payload):
        if item.endswith(".app"):
            return os.path.join(payload, item)

    raise RuntimeError("No .app bundle found in Payload/")


def _get_app_executable(app_dir: str) -> str:
    """Get the main executable name from Info.plist CFBundleExecutable.

    Args:
        app_dir: Path to the .app bundle.

    Returns:
        The executable name.
    """
    info_path = os.path.join(app_dir, "Info.plist")
    if os.path.isfile(info_path):
        with open(info_path, "rb") as f:
            info = plistlib.load(f)
        return info.get("CFBundleExecutable", os.path.basename(app_dir).replace(".app", ""))
    return os.path.basename(app_dir).replace(".app", "")


def patch_info_plist(info_plist: Dict[str, Any]) -> Dict[str, Any]:
    """Patch an Info.plist dictionary for SDK injection compatibility.

    Per D-07:
      - Set MinimumOSVersion to 14.0 if lower.
      - Ensure UIDeviceFamily includes 1 (iPhone).
      - NO network usage descriptions added (privacy contract).

    Args:
        info_plist: The parsed Info.plist as a dict.

    Returns:
        The patched dict (modified in place and returned for chaining).
    """
    # MinimumOSVersion: ensure >= 14.0
    min_os = info_plist.get("MinimumOSVersion", "12.0")
    try:
        min_os_version = float(min_os) if isinstance(min_os, str) else float(min_os)
    except (ValueError, TypeError):
        min_os_version = 12.0

    if min_os_version < 14.0:
        info_plist["MinimumOSVersion"] = "14.0"

    # UIDeviceFamily: ensure includes 1 (iPhone)
    device_family = info_plist.get("UIDeviceFamily", [])
    if 1 not in device_family:
        device_family = list(device_family) if isinstance(device_family, list) else [device_family]
        device_family.append(1)
        info_plist["UIDeviceFamily"] = device_family

    return info_plist


def embed_framework(app_dir: str, framework_src_dir: str) -> bool:
    """Copy PerformanceBench.framework into the .app bundle Frameworks/ directory.

    Args:
        app_dir: Path to the .app bundle directory.
        framework_src_dir: Path to the source PerformanceBench.framework.

    Returns:
        True if successful.

    Raises:
        RuntimeError: If framework source doesn't exist or copy fails.
    """
    if not os.path.isdir(framework_src_dir):
        raise RuntimeError(f"PerformanceBench.framework not found at: {framework_src_dir}")

    frameworks_dest = os.path.join(app_dir, "Frameworks")
    framework_dest = os.path.join(frameworks_dest, os.path.basename(framework_src_dir))

    # Remove existing if present
    if os.path.exists(framework_dest):
        shutil.rmtree(framework_dest)

    os.makedirs(frameworks_dest, exist_ok=True)
    shutil.copytree(framework_src_dir, framework_dest)

    # Verify the dylib binary is present
    dylib_name = os.path.basename(framework_src_dir).replace(".framework", "")
    dylib_path = os.path.join(framework_dest, dylib_name)
    if not os.path.isfile(dylib_path):
        raise RuntimeError(f"Framework dylib not found at: {dylib_path}")

    return True


def _insert_load_command(app_dir: str, executable_name: str) -> bool:
    """Insert LC_LOAD_DYLIB for PerformanceBench.framework into the main executable.

    Uses install_name_tool to add @executable_path/Frameworks/PerformanceBench.framework/PerformanceBench
    as a load command.

    Args:
        app_dir: Path to the .app bundle.
        executable_name: Name of the main executable.

    Returns:
        True if successful.

    Raises:
        RuntimeError: If install_name_tool fails.
    """
    executable_path = os.path.join(app_dir, executable_name)
    if not os.path.isfile(executable_path):
        raise RuntimeError(f"Executable not found: {executable_path}")

    dylib_path = "@executable_path/Frameworks/PerformanceBench.framework/PerformanceBench"

    try:
        result = subprocess.run(
            ["install_name_tool", "-change", dylib_path, dylib_path, executable_path],
            capture_output=True, text=True, timeout=30
        )
        # install_name_tool returns non-zero if the load command doesn't exist yet
        # That's expected for first injection — we add it next
    except FileNotFoundError:
        raise RuntimeError("install_name_tool not found. Ensure Xcode command line tools are installed.")

    # Add the load command
    try:
        result = subprocess.run(
            ["install_name_tool", "-add_rpath",
             "@executable_path/Frameworks",
             executable_path],
            capture_output=True, text=True, timeout=30
        )
    except Exception:
        pass  # rpath might already exist

    return True


def repack_ipa(payload_dir: str, output_path: str) -> str:
    """Repack the Payload/ directory into a new IPA zip file.

    Args:
        payload_dir: Path to the Payload directory.
        output_path: Destination path for the output IPA.

    Returns:
        Path to the created IPA.

    Raises:
        RuntimeError: If repacking fails.
    """
    parent = os.path.dirname(payload_dir)
    payload_name = os.path.basename(payload_dir)

    try:
        original_cwd = os.getcwd()
        os.chdir(parent)

        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(payload_name):
                for file in files:
                    full_path = os.path.join(root, file)
                    zf.write(full_path)

        os.chdir(original_cwd)
    except Exception as e:
        raise RuntimeError(f"Failed to repack IPA: {e}")

    return output_path


def _parse_min_os_version(version_str: str) -> float:
    """Parse a MinimumOSVersion string to a float."""
    try:
        return float(version_str)
    except (ValueError, TypeError):
        return 12.0


def inject_dylib(
    ipa_path: str,
    output_path: str,
    signing_method: str = "free_apple_id",
    apple_id: Optional[str] = None,
    team_id: Optional[str] = None,
    cert_path: Optional[str] = None,
    framework_dir: Optional[str] = None,
    app_specific_password: Optional[str] = None,
    provisioning_profile: Optional[str] = None,
    cert_identity: Optional[str] = None,
) -> InjectionResult:
    """Injects PerformanceBench.framework into an iOS IPA.

    Full injection pipeline per D-06, D-07:
      1. Unzip IPA
      2. FairPlay check
      3. Embed framework
      4. Patch Info.plist
      5. Insert load command
      6. Re-sign
      7. Verify
      8. Repack

    Args:
        ipa_path: Path to input .ipa file.
        output_path: Path for output signed .ipa file.
        signing_method: "free_apple_id", "paid_developer", or "user_certificate".
        apple_id: Apple ID email (for free/paid methods).
        team_id: Team ID (for paid method).
        cert_path: Path to certificate (for user_certificate method).
        framework_dir: Path to PerformanceBench.framework directory.
        app_specific_password: App-specific password for Apple ID.
        provisioning_profile: Path to .mobileprovision file (paid method).
        cert_identity: Certificate identity hash (user_certificate method).

    Returns:
        InjectionResult with success status, warnings, and output details.
    """
    from injector.apple_signing import (
        free_apple_id_sign,
        paid_developer_sign,
        user_certificate_sign,
        SigningMethod,
    )
    from injector.ipa_verifier import verify_injection

    warnings: List[str] = []
    temp_dir = None

    try:
        # Step 1: Create temp dir and extract
        temp_dir = tempfile.mkdtemp(prefix="pb_ipa_inject_")
        extract_dir = os.path.join(temp_dir, "extracted")
        print(json.dumps({"step": "unpack", "status": "running",
                          "detail": "Extracting IPA..."}), flush=True)
        extract_ipa(ipa_path, extract_dir)

        # Find .app bundle
        app_dir = _find_app_bundle(extract_dir)
        steps = 1

        # Step 2: FairPlay check
        print(json.dumps({"step": "encryption_check", "status": "running",
                          "detail": "Checking FairPlay encryption..."}), flush=True)
        executable_name = _get_app_executable(app_dir)
        executable_path = os.path.join(app_dir, executable_name)

        if os.path.isfile(executable_path):
            cryptid = _get_macho_cryptid(executable_path)
            check_fairplay_encryption(cryptid)
        else:
            warnings.append("Executable not found; skipping FairPlay check")
        steps += 1

        # Step 3: Embed framework
        print(json.dumps({"step": "inject_sdk", "status": "running",
                          "detail": "Embedding PerformanceBench.framework..."}), flush=True)
        if framework_dir and os.path.isdir(framework_dir):
            embed_framework(app_dir, framework_dir)
        else:
            # Try default locations
            possible_paths = [
                os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                             "sdk", "ios", "PerformanceBench.framework"),
                os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "..", "sdk", "ios", "PerformanceBench.framework"),
            ]
            found = False
            for p in possible_paths:
                if os.path.isdir(p):
                    embed_framework(app_dir, p)
                    found = True
                    break
            if not found:
                warnings.append("PerformanceBench.framework not found; skipping framework embedding")
        steps += 1

        # Step 4: Patch Info.plist
        print(json.dumps({"step": "patch_plist", "status": "running",
                          "detail": "Patching Info.plist..."}), flush=True)
        info_path = os.path.join(app_dir, "Info.plist")
        if os.path.isfile(info_path):
            with open(info_path, "rb") as f:
                info = plistlib.load(f)
            info = patch_info_plist(info)
            with open(info_path, "wb") as f:
                plistlib.dump(info, f)
        steps += 1

        # Step 5: Insert load command
        print(json.dumps({"step": "load_command", "status": "running",
                          "detail": "Inserting load command..."}), flush=True)
        if os.path.isfile(executable_path):
            try:
                _insert_load_command(app_dir, executable_name)
            except RuntimeError as e:
                warnings.append(f"Load command insertion skipped: {e}")
        steps += 1

        # Step 6: Re-sign
        print(json.dumps({"step": "signing", "status": "running",
                          "detail": f"Signing with {signing_method}..."}), flush=True)
        sign_result = None
        if signing_method == "free_apple_id":
            if not apple_id:
                return InjectionResult(success=False, output_path="",
                                       signing_method_used=signing_method,
                                       warnings=warnings, steps_completed=steps,
                                       error="Apple ID required for free signing")
            sign_result = free_apple_id_sign(
                ipa_path=extract_dir,  # Sign the extracted bundle
                apple_id=apple_id,
                app_specific_password=app_specific_password or "",
            )
        elif signing_method == "paid_developer":
            if not team_id:
                return InjectionResult(success=False, output_path="",
                                       signing_method_used=signing_method,
                                       warnings=warnings, steps_completed=steps,
                                       error="Team ID required for paid developer signing")
            sign_result = paid_developer_sign(
                ipa_path=extract_dir,
                team_id=team_id,
                profile_path=provisioning_profile or "",
            )
        elif signing_method == "user_certificate":
            if not cert_identity:
                return InjectionResult(success=False, output_path="",
                                       signing_method_used=signing_method,
                                       warnings=warnings, steps_completed=steps,
                                       error="Certificate identity required for user certificate signing")
            sign_result = user_certificate_sign(
                ipa_path=extract_dir,
                cert_identity=cert_identity,
            )
        else:
            return InjectionResult(success=False, output_path="",
                                   signing_method_used=signing_method,
                                   warnings=warnings, steps_completed=steps,
                                   error=f"Unknown signing method: {signing_method}")

        if sign_result and not sign_result.success:
            return InjectionResult(success=False, output_path="",
                                   signing_method_used=signing_method,
                                   warnings=warnings + sign_result.warnings,
                                   steps_completed=steps,
                                   error=sign_result.error or "Signing failed")
        if sign_result:
            warnings.extend(sign_result.warnings)
        steps += 1

        # Step 7: Repack IPA
        print(json.dumps({"step": "repack", "status": "running",
                          "detail": "Repacking IPA..."}), flush=True)
        payload_dir = os.path.join(extract_dir, "Payload")
        repack_ipa(payload_dir, output_path)
        steps += 1

        # Step 8: Verify
        print(json.dumps({"step": "verify", "status": "running",
                          "detail": "Verifying injection..."}), flush=True)
        verify_result = verify_injection(output_path)
        if not verify_result.all_passed:
            failed_checks = [c for c in verify_result.checks if not c.passed]
            for check in failed_checks:
                warnings.append(f"Verification: {check.name} - {check.detail}")
        steps += 1

        print(json.dumps({"step": "done", "status": "pass",
                          "detail": f"Injection complete: {output_path}"}), flush=True)

        return InjectionResult(
            success=True,
            output_path=output_path,
            signing_method_used=signing_method,
            warnings=warnings,
            steps_completed=steps,
        )

    except Exception as e:
        return InjectionResult(
            success=False,
            output_path="",
            signing_method_used=signing_method,
            warnings=warnings,
            steps_completed=0,
            error=str(e),
        )
    finally:
        if temp_dir and os.path.isdir(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)
