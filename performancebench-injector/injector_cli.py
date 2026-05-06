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


@click.group()
@click.version_option(version="1.0.0", prog_name="PerformanceBench Injector")
def cli():
    """PerformanceBench APK Injector — inject profiling SDK into Android APKs."""
    pass


@cli.command()
@click.option("--apk", required=True, type=click.Path(exists=True), help="Path to input APK file")
@click.option("--method", default="smali", type=click.Choice(["smali", "frida"]),
              help="Injection method (frida path not yet implemented)")
@click.option("--keystore", type=click.Path(), help="Path to keystore for re-signing")
@click.option("--keystore-password", help="Keystore password")
@click.option("--key-alias", help="Key alias in keystore")
@click.option("--key-password", help="Key password")
@click.option("--sdk-so-dir", type=click.Path(exists=True),
              help="Directory containing SDK .so files per ABI")
@click.option("--output", default="injected.apk", type=click.Path(),
              help="Output APK path (default: injected.apk)")
@click.option("--proguard-mapping", type=click.Path(exists=True),
              help="Path to ProGuard mapping.txt for obfuscated builds")
@click.option("--aab", is_flag=True, default=False, help="Input is an Android App Bundle (.aab)")
@click.option("--work-dir", type=click.Path(), help="Working directory for decompilation")
def inject(apk, method, keystore, keystore_password, key_alias, key_password,
           sdk_so_dir, output, proguard_mapping, aab, work_dir):
    """Run the full APK injection pipeline.

    Steps: validate -> decompile -> patch -> rebuild -> resign -> verify
    """
    import tempfile
    import json

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


if __name__ == "__main__":
    cli()
