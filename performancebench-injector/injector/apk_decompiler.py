"""APK decompiler — wraps apktool for APK decode and AAB conversion.

Per D-06: Monorepo sibling at performancebench-injector/.
Per D-05: Full APK + AAB compatibility.
Per T-04-01: Validate APK magic bytes before decompile.
"""

import os
import subprocess
import zipfile
from dataclasses import dataclass


class ApkValidationError(Exception):
    """Raised when the input APK is invalid."""
    pass


class DecompileError(Exception):
    """Raised when apktool decompilation fails."""
    pass


@dataclass
class DecompileResult:
    """Result of APK decompilation."""
    success: bool
    output_dir: str
    stdout: str = ""
    stderr: str = ""


def validate_apk(apk_path: str) -> bool:
    """Validate that the file at apk_path is a valid APK (ZIP with magic bytes).

    Args:
        apk_path: Path to the APK file.

    Returns:
        True if the file is a valid APK.

    Raises:
        ApkValidationError: If the file is not a valid APK.
    """
    if not os.path.isfile(apk_path):
        raise ApkValidationError(
            f"APK file not found: {apk_path}"
        )

    # Validate ZIP magic bytes (PK\x03\x04) — per T-04-01
    try:
        with open(apk_path, "rb") as f:
            magic = f.read(4)
            if magic != b"PK\x03\x04":
                raise ApkValidationError(
                    f"File is not a valid APK (missing ZIP magic bytes): {apk_path}"
                )
    except OSError as e:
        raise ApkValidationError(
            f"Cannot read APK file: {apk_path}: {e}"
        )

    # Verify it's a valid ZIP
    try:
        with zipfile.ZipFile(apk_path, "r") as zf:
            # Check for bad zip
            bad = zf.testzip()
            if bad is not None:
                raise ApkValidationError(
                    f"APK contains corrupt entry: {bad}"
                )
    except zipfile.BadZipFile as e:
        raise ApkValidationError(
            f"File is not a valid ZIP/APK: {apk_path}: {e}"
        )

    return True


def decompile_apk(
    apk_path: str,
    output_dir: str,
    apktool_path: str = "apktool",
    no_res: bool = False,
) -> DecompileResult:
    """Decompile an APK using apktool.

    Args:
        apk_path: Path to the input APK file.
        output_dir: Directory for decoded output.
        apktool_path: Path to apktool executable/batch file.
        no_res: If True, skip resource decoding (--no-res flag).

    Returns:
        DecompileResult with success status.

    Raises:
        RuntimeError: If apktool fails.
    """
    # Validate input first
    validate_apk(apk_path)

    # Build apktool command. We always need smali decoded (the whole point
    # of the injector — smali_patcher walks the decoded smali files for the
    # Application subclass). The previous code did `-s` here, which is
    # apktool's flag for *skipping smali decoding* — it confused `-s` with
    # `--no-res`. Net effect: the default flow produced an `apktool d`
    # output with no smali files, find_application_smali() returned None,
    # and the injector silently shipped an unmodified APK that "succeeded"
    # but ran without the SDK (B-085).
    #
    # Keep the `no_res` knob so callers that only need the manifest can
    # still skip resource decoding for speed; default behaviour now decodes
    # both resources and smali.
    cmd = [apktool_path, "d", "-f"]
    if no_res:
        cmd.append("--no-res")

    # Clean output dir if it exists
    if os.path.exists(output_dir):
        import shutil
        shutil.rmtree(output_dir, ignore_errors=True)

    cmd.extend(["-o", output_dir, apk_path])

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=300,  # 5-minute timeout
    )

    if result.returncode != 0:
        stderr = result.stderr or result.stdout
        raise RuntimeError(
            f"apktool decompile failed (exit code {result.returncode}): "
            f"{stderr.strip()[:500]}"
        )

    return DecompileResult(
        success=True,
        output_dir=output_dir,
        stdout=result.stdout,
        stderr=result.stderr,
    )
