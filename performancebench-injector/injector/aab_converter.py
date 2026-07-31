"""AAB to APK converter — wraps bundletool for universal APK generation.

Per D-05: Full AAB compatibility via bundletool conversion.
Keystore + key passwords are routed via environment variables
(`env:VAR_NAME` pass spec) so they don't leak through the process
command line (T-04-02 / B-095).
"""

import os
import subprocess
import tempfile


# Environment variable names that bundletool reads via `env:VAR_NAME`.
_KS_PASS_VAR = "PB_KS_PASS"
_KEY_PASS_VAR = "PB_KEY_PASS"


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

    # Inherit parent env; layer password vars only when signing.
    env = os.environ.copy()

    # Add signing if keystore provided — passwords via env:VAR (B-095)
    if keystore_path and key_alias:
        cmd.extend([
            f"--ks={keystore_path}",
            f"--ks-key-alias={key_alias}",
        ])
        if keystore_password:
            env[_KS_PASS_VAR] = keystore_password
            cmd.append(f"--ks-pass=env:{_KS_PASS_VAR}")
        if key_password:
            env[_KEY_PASS_VAR] = key_password
            cmd.append(f"--key-pass=env:{_KEY_PASS_VAR}")

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=300,
        env=env,
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
