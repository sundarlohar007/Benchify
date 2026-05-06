"""AAB to APK converter — wraps bundletool for universal APK generation.

Per D-05: Full AAB compatibility via bundletool conversion.
"""

import os
import subprocess
import tempfile


class AabConversionError(Exception):
    """Raised when AAB conversion fails."""
    pass


def convert_aab_to_apk(
    aab_path: str,
    output_dir: str,
    bundletool_path: str = "bundletool",
    keystore_path: str = "",
    keystore_password: str = "",
    key_alias: str = "",
    key_password: str = "",
) -> str:
    """Convert an Android App Bundle (.aab) to a universal APK using bundletool.

    Args:
        aab_path: Path to the .aab file.
        output_dir: Directory for the output APK.
        bundletool_path: Path to bundletool JAR or executable.
        keystore_path: Path to keystore for signing (optional).
        keystore_password: Keystore password.
        key_alias: Key alias.
        key_password: Key password.

    Returns:
        Path to the generated universal APK.

    Raises:
        AabConversionError: If conversion fails or input is missing.
    """
    if not os.path.isfile(aab_path):
        raise AabConversionError(
            f"AAB file not found: {aab_path}"
        )

    os.makedirs(output_dir, exist_ok=True)

    apks_output = os.path.join(output_dir, "universal.apks")
    universal_apk = os.path.join(output_dir, "universal.apk")

    # Build bundletool command for universal APK
    cmd = [
        "java", "-jar", bundletool_path,
        "build-apks",
        f"--bundle={aab_path}",
        f"--output={apks_output}",
        "--mode=universal",
        "--overwrite",
    ]

    # Add signing if keystore provided
    if keystore_path and key_alias:
        cmd.extend([
            f"--ks={keystore_path}",
            f"--ks-key-alias={key_alias}",
        ])
        if keystore_password:
            cmd.append(f"--ks-pass=pass:{keystore_password}")
        if key_password:
            cmd.append(f"--key-pass=pass:{key_password}")

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=300,
    )

    if result.returncode != 0:
        raise AabConversionError(
            f"bundletool conversion failed (exit code {result.returncode}): "
            f"{result.stderr.strip()[:500]}"
        )

    # Extract the universal APK from the .apks (which is a ZIP)
    import zipfile
    try:
        with zipfile.ZipFile(apks_output, "r") as zf:
            # Find the universal APK inside
            apk_names = [
                n for n in zf.namelist()
                if n.endswith(".apk") and ("universal" in n.lower() or "standalones" in n.lower())
            ]
            if not apk_names:
                # Fallback: just extract any .apk
                apk_names = [n for n in zf.namelist() if n.endswith(".apk")]

            if apk_names:
                zf.extract(apk_names[0], output_dir)
                extracted = os.path.join(output_dir, apk_names[0])
                if extracted != universal_apk:
                    import shutil
                    shutil.move(extracted, universal_apk)

        # Clean up .apks file
        os.remove(apks_output)

    except zipfile.BadZipFile as e:
        raise AabConversionError(f"bundletool output is not a valid .apks file: {e}")

    if not os.path.isfile(universal_apk):
        raise AabConversionError(
            "Conversion completed but universal APK was not found in output"
        )

    return universal_apk
