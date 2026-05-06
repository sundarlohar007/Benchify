#!/usr/bin/env python3
"""PerformanceBench APK Injector CLI.

Per D-09: CLI for scripting. GUI is desktop-only.
Per D-06: Monorepo sibling at performancebench-injector/.

Subcommands:
    inject   — Full pipeline: decompile -> patch -> rebuild -> resign -> verify
    verify   — Run verification steps only on an already-injected APK
    resign   — Re-sign an already-built APK
"""

import sys
import os

# Add the current directory to path so imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import click
from injector.apk_decompiler import validate_apk, decompile_apk
from injector.smali_patcher import find_application_smali, patch_smali
from injector.manifest_patcher import patch_manifest
from injector.frida_injector import FridaInjector


@click.group()
@click.version_option(version="1.0.0", prog_name="PerformanceBench Injector")
def cli():
    """PerformanceBench APK Injector — inject profiling SDK into Android APKs."""
    pass


@cli.command()
@click.option("--apk", required=True, type=click.Path(exists=True), help="Path to input APK file")
@click.option("--method", default="smali", type=click.Choice(["smali", "frida"]),
              help="Injection method: smali (permanent, re-sign) or frida (no re-sign, needs frida-server)")
@click.option("--keystore", type=click.Path(), help="Path to keystore for re-signing (smali only)")
@click.option("--keystore-password", help="Keystore password (smali only)")
@click.option("--key-alias", help="Key alias in keystore (smali only)")
@click.option("--key-password", help="Key password (smali only)")
@click.option("--sdk-so-dir", type=click.Path(exists=True),
              help="Directory containing SDK .so files per ABI (smali only)")
@click.option("--gadget-so", type=click.Path(exists=True),
              help="Path to frida-gadget-<arch>.so file (required for frida method)")
@click.option("--gadget-config", type=click.Path(),
              help="Path to custom gadget config JSON (optional, frida method)")
@click.option("--output", default="injected.apk", type=click.Path(),
              help="Output APK path (default: injected.apk)")
@click.option("--proguard-mapping", type=click.Path(exists=True),
              help="Path to ProGuard mapping.txt for obfuscated builds (smali only)")
@click.option("--aab", is_flag=True, default=False, help="Input is an Android App Bundle (.aab)")
@click.option("--work-dir", type=click.Path(), help="Working directory for decompilation (smali only)")
def inject(apk, method, keystore, keystore_password, key_alias, key_password,
           sdk_so_dir, gadget_so, gadget_config, output, proguard_mapping, aab, work_dir):
    """Run the full APK injection pipeline.

    Two injection paths:

    Smali path (--method smali):
        Steps: validate -> decompile -> patch -> rebuild -> resign -> verify
        Requires: keystore, apktool

    Frida path (--method frida):
        Steps: validate -> detect arch -> inject gadget .so + config
        Requires: --gadget-so (frida-gadget .so file)
        Does NOT require: keystore, apktool
        Original APK signature is preserved.
        Recommended for CI/CD automation (per D-25).
    """
    import tempfile

    # ---- Frida gadget path (per D-09, D-25) ----
    if method == "frida":
        _inject_frida(apk, gadget_so, gadget_config, output)
        return

    # ---- Smali path (per D-01, D-04, D-07) ----
    click.echo(json.dumps({"step": "validate", "status": "running", "detail": "Validating APK..."}))
    validate_apk(apk)

    tmpdir = work_dir if work_dir else tempfile.mkdtemp(prefix="pb_inject_")

    click.echo(json.dumps({"step": "decompile", "status": "running", "detail": "Decompiling APK with apktool..."}))
    decompile_apk(apk, os.path.join(tmpdir, "decoded"))

    click.echo(json.dumps({"step": "smali", "status": "running", "detail": "Patching Smali bytecode..."}))
    decoded_dir = os.path.join(tmpdir, "decoded")
    app_smali = find_application_smali(decoded_dir)
    if app_smali:
        with open(app_smali, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
        patched = patch_smali(content)
        with open(app_smali, "w", encoding="utf-8") as f:
            f.write(patched)
    else:
        click.echo(json.dumps({"step": "smali", "status": "warning",
                               "detail": "No Application subclass found. SDK may not initialize automatically."}))

    click.echo(json.dumps({"step": "manifest", "status": "running", "detail": "Patching AndroidManifest.xml..."}))
    manifest_path = os.path.join(decoded_dir, "AndroidManifest.xml")
    if os.path.isfile(manifest_path):
        with open(manifest_path, "r", encoding="utf-8", errors="ignore") as f:
            manifest_xml = f.read()
        patched_manifest = patch_manifest(manifest_xml)
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(patched_manifest)

    click.echo(json.dumps({"step": "rebuild", "status": "running", "detail": "Rebuilding APK with apktool..."}))
    _rebuild_apk(decoded_dir, os.path.join(tmpdir, "unsigned.apk"))

    click.echo(json.dumps({"step": "resign", "status": "running", "detail": "Re-signing APK..."}))
    if keystore:
        from injector.resigner import resign
        resign(
            os.path.join(tmpdir, "unsigned.apk"),
            keystore, keystore_password or "", key_alias or "",
            key_password or "", output,
        )
    else:
        msg = "No keystore provided. APK is unsigned. Use 'resign' subcommand."
        click.echo(json.dumps({"step": "resign", "status": "warning", "detail": msg}))

    click.echo(json.dumps({"step": "done", "status": "pass", "detail": f"Injection complete: {output}"}))



def _inject_frida(apk: str, gadget_so: str, gadget_config: str, output: str):
    """Run the Frida gadget injection pipeline.

    Per D-09, D-25: Frida path for CI/CD. No apktool, no re-sign.
    """
    import json as json_mod

    if not gadget_so:
        msg = "Frida method requires --gadget-so (path to frida-gadget-<arch>.so)"
        click.echo(json_mod.dumps({"step": "frida", "status": "fail", "detail": msg}))
        raise click.UsageError(msg)

    click.echo(json_mod.dumps({"step": "frida",
                                "status": "running",
                                "detail": "Injecting frida-gadget into APK via ZIP..."}))

    config_content = None
    if gadget_config:
        try:
            with open(gadget_config, "r", encoding="utf-8") as f:
                config_content = f.read()
        except OSError as e:
            click.echo(json_mod.dumps({"step": "frida",
                                        "status": "warning",
                                        "detail": f"Could not read gadget config: {e}. Using default."}))

    injector = FridaInjector()
    result = injector.inject(
        apk_path=apk,
        gadget_so_path=gadget_so,
        output_path=output,
        config_json=config_content,
    )

    if result.get("status") == "ok":
        click.echo(json_mod.dumps({
            "step": "frida",
            "status": "pass",
            "detail": f"Frida gadget injected. Arch: {result.get('detected_arch', 'unknown')}",
        }))
        for i, step in enumerate(result.get("verification_steps", []), 1):
            click.echo(json_mod.dumps({
                "step": "verify",
                "status": "info",
                "detail": f"Verification step {i}: {step}",
            }))
        click.echo(json_mod.dumps({"step": "done", "status": "pass",
                                     "detail": f"Injection complete: {output}"}))
    else:
        click.echo(json_mod.dumps({"step": "frida", "status": "fail",
                                     "detail": result.get("error", "Unknown error")}))


def _rebuild_apk(decoded_dir: str, output_path: str):
    """Rebuild APK from decoded directory using apktool."""
    import subprocess

    cmd = ["apktool", "b", decoded_dir, "-o", output_path]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        raise RuntimeError(f"apktool rebuild failed: {result.stderr.strip()[:500]}")


@cli.command()
@click.option("--apk", required=True, type=click.Path(exists=True), help="Path to APK to verify")
@click.option("--keystore", type=click.Path(exists=True), help="Path to keystore for apksigner verify")
@click.option("--device-serial", help="ADB device serial for connectivity test")
@click.option("--package", help="Package name for ADB install/launch test")
def verify(apk, keystore, device_serial, package):
    """Run verification steps on an already-injected APK.

    Steps: apksigner verify -> Smali patch validation -> ADB port connectivity test
    """
    import json
    from injector.verifier import verify_apksigner, verify_smali_patch, verify_adb_connectivity

    # Step 1: apksigner verify
    click.echo(json.dumps({"step": "apksigner_verify", "status": "running", "detail": "Verifying signature..."}))
    try:
        verify_apksigner(apk)
        click.echo(json.dumps({"step": "apksigner_verify", "status": "pass", "detail": "Signature valid"}))
    except Exception as e:
        click.echo(json.dumps({"step": "apksigner_verify", "status": "fail", "detail": str(e)}))

    # Step 2: Smali patch validation
    click.echo(json.dumps({"step": "smali_verify", "status": "running", "detail": "Checking SDK injection..."}))
    try:
        verify_smali_patch(apk)
        click.echo(json.dumps({"step": "smali_verify", "status": "pass", "detail": "SDK init found"}))
    except Exception as e:
        click.echo(json.dumps({"step": "smali_verify", "status": "fail", "detail": str(e)}))

    # Step 3: ADB connectivity test
    if device_serial and package:
        click.echo(json.dumps({"step": "adb_connectivity", "status": "running",
                               "detail": "Testing ADB port 8080 connectivity..."}))
        try:
            verify_adb_connectivity(device_serial, package)
            click.echo(json.dumps({"step": "adb_connectivity", "status": "pass",
                                   "detail": "Port 8080 reachable"}))
        except Exception as e:
            click.echo(json.dumps({"step": "adb_connectivity", "status": "fail", "detail": str(e)}))
    else:
        click.echo(json.dumps({"step": "adb_connectivity", "status": "skipped",
                               "detail": "No device serial/package provided"}))


@cli.command()
@click.option("--apk", required=True, type=click.Path(exists=True), help="Path to APK to re-sign")
@click.option("--keystore", required=True, type=click.Path(exists=True), help="Path to keystore")
@click.option("--keystore-password", help="Keystore password")
@click.option("--key-alias", required=True, help="Key alias")
@click.option("--key-password", help="Key password")
@click.option("--output", default="resigned.apk", type=click.Path(), help="Output APK path")
def resign(apk, keystore, keystore_password, key_alias, key_password, output):
    """Re-sign an already-built APK with a keystore."""
    import json
    from injector.resigner import resign as do_resign

    click.echo(json.dumps({"step": "resign", "status": "running", "detail": "Re-signing APK..."}))
    do_resign(
        apk, keystore, keystore_password or "", key_alias,
        key_password or "", output,
    )
    click.echo(json.dumps({"step": "resign", "status": "pass", "detail": f"Signed: {output}"}))


# ---- iOS IPA Injection & Signing Commands (per 05-02-PLAN Task 1) ----


@cli.command(name="ipa-inject")
@click.option("--input", "input_ipa", required=True, type=click.Path(exists=True),
              help="Path to input .ipa file")
@click.option("--output", default="injected.ipa", type=click.Path(),
              help="Output IPA path (default: injected.ipa)")
@click.option("--signing", default="free", type=click.Choice(["free", "paid", "cert"]),
              help="Signing method: free (Apple ID), paid (Developer), cert (User certificate)")
@click.option("--apple-id", help="Apple ID email (required for free/paid signing)")
@click.option("--team-id", help="Apple Developer Team ID (required for paid signing)")
@click.option("--framework-dir", type=click.Path(exists=True),
              help="Path to PerformanceBench.framework directory")
@click.option("--app-specific-password", help="App-specific password for Apple ID")
@click.option("--profile-path", type=click.Path(exists=True),
              help="Path to .mobileprovision provisioning profile (paid signing)")
@click.option("--cert-identity", help="Certificate identity hash (user certificate signing)")
def ipa_inject(input_ipa, output, signing, apple_id, team_id, framework_dir,
               app_specific_password, profile_path, cert_identity):
    """Inject PerformanceBench.framework into an iOS IPA.

    Steps: extract -> FairPlay check -> embed framework -> patch Info.plist ->
           insert load command -> sign -> verify -> repack

    Examples:
        python injector_cli.py ipa-inject --input app.ipa --output app-injected.ipa --signing free --apple-id user@icloud.com
        python injector_cli.py ipa-inject --input app.ipa --signing paid --apple-id user@icloud.com --team-id ABC123 --profile-path profile.mobileprovision
        python injector_cli.py ipa-inject --input app.ipa --signing cert --cert-identity ABC123DEF456
    """
    import json as json_mod
    from injector.ipa_injector import inject_dylib, InjectionResult

    # Map signing method
    method_map = {
        "free": "free_apple_id",
        "paid": "paid_developer",
        "cert": "user_certificate",
    }
    signing_method = method_map.get(signing, "free_apple_id")

    # Progress reporting
    click.echo(json_mod.dumps({"step": "ipa_inject", "status": "running",
                                "detail": f"Starting IPA injection with {signing_method}..."}))

    result = inject_dylib(
        ipa_path=input_ipa,
        output_path=output,
        signing_method=signing_method,
        apple_id=apple_id,
        team_id=team_id,
        framework_dir=framework_dir,
        app_specific_password=app_specific_password,
        provisioning_profile=profile_path,
        cert_identity=cert_identity,
    )

    if result.success:
        click.echo(json_mod.dumps({"step": "done", "status": "pass",
                                    "detail": f"IPA injected successfully: {output}",
                                    "signing_method": result.signing_method_used,
                                    "warnings": result.warnings}))
    else:
        click.echo(json_mod.dumps({"step": "error", "status": "fail",
                                    "detail": result.error or "Injection failed",
                                    "warnings": result.warnings}))


@cli.command(name="ipa-verify")
@click.option("--input", "input_ipa", required=True, type=click.Path(exists=True),
              help="Path to injected .ipa file to verify")
def ipa_verify(input_ipa):
    """Verify an injected IPA has correct structure and framework embedding.

    Checks: IPA structure, PerformanceBench.framework, load commands, code signature.
    """
    import json as json_mod
    from injector.ipa_verifier import verify_injection

    click.echo(json_mod.dumps({"step": "ipa_verify", "status": "running",
                                "detail": "Verifying IPA injection..."}))

    result = verify_injection(input_ipa)

    if result.all_passed:
        click.echo(json_mod.dumps({"step": "done", "status": "pass",
                                    "detail": "All verification checks passed",
                                    "checks": [
                                        {"name": c.name, "passed": c.passed, "detail": c.detail}
                                        for c in result.checks
                                    ]}))
    else:
        failed = [c for c in result.checks if not c.passed]
        click.echo(json_mod.dumps({"step": "done", "status": "fail",
                                    "detail": f"{len(failed)} check(s) failed",
                                    "checks": [
                                        {"name": c.name, "passed": c.passed, "detail": c.detail}
                                        for c in result.checks
                                    ]}))


@cli.command(name="signing-detect")
def signing_detect():
    """Detect available iOS code signing methods and print as JSON.

    Checks: free Apple ID (altool), paid developer (provisioning profiles),
            user certificate (security find-identity).

    Output: JSON array of available signing method names.
    """
    import json as json_mod
    from injector.apple_signing import detect_available_methods, SigningMethod

    methods = detect_available_methods()
    result = {
        "available_methods": [m.value for m in methods],
        "count": len(methods),
        "details": {
            "free_apple_id": any(m == SigningMethod.FREE_APPLE_ID for m in methods),
            "paid_developer": any(m == SigningMethod.PAID_DEVELOPER for m in methods),
            "user_certificate": any(m == SigningMethod.USER_CERTIFICATE for m in methods),
        },
    }
    click.echo(json_mod.dumps(result))


@cli.command(name="ipa-metadata")
@click.option("--input", "input_ipa", required=True, type=click.Path(exists=True),
              help="Path to .ipa file to read metadata from")
def ipa_metadata(input_ipa):
    """Read metadata from an IPA file and output as JSON.

    Extracts: app name, bundle ID, version, minimum OS, encryption status.
    """
    import json as json_mod
    import zipfile
    import plistlib
    import tempfile
    import os as os_mod

    result = {
        "app_name": None,
        "bundle_id": None,
        "version": None,
        "minimum_os": None,
        "encrypted": None,
        "error": None,
    }

    try:
        if not zipfile.is_zipfile(input_ipa):
            result["error"] = "Not a valid IPA file"
            click.echo(json_mod.dumps(result))
            return

        with zipfile.ZipFile(input_ipa, "r") as zf:
            # Find Info.plist
            plist_paths = [n for n in zf.namelist()
                           if "Payload/" in n and n.endswith(".app/Info.plist")]
            if not plist_paths:
                result["error"] = "No Info.plist found in IPA"
                click.echo(json_mod.dumps(result))
                return

            plist_data = zf.read(plist_paths[0])
            info = plistlib.loads(plist_data)

            result["app_name"] = info.get("CFBundleDisplayName") or info.get("CFBundleName")
            result["bundle_id"] = info.get("CFBundleIdentifier")
            result["version"] = info.get("CFBundleShortVersionString")
            result["minimum_os"] = info.get("MinimumOSVersion")

            # Check encryption status
            exec_name = info.get("CFBundleExecutable")
            if exec_name:
                # Find the executable in the zip
                app_prefix = plist_paths[0].replace("Info.plist", "")
                exec_in_zip = app_prefix + exec_name
                if exec_in_zip in zf.namelist():
                    # Extract and check cryptid
                    tmpdir = tempfile.mkdtemp(prefix="pb_metadata_")
                    try:
                        zf.extract(exec_in_zip, tmpdir)
                        extracted_path = os_mod.path.join(tmpdir, exec_in_zip)
                        from injector.ipa_injector import _get_macho_cryptid
                        cryptid = _get_macho_cryptid(extracted_path)
                        result["encrypted"] = cryptid is not None and cryptid != 0
                    finally:
                        import shutil
                        shutil.rmtree(tmpdir, ignore_errors=True)

        click.echo(json_mod.dumps(result))
    except Exception as e:
        result["error"] = str(e)
        click.echo(json_mod.dumps(result))


if __name__ == "__main__":
    cli()
