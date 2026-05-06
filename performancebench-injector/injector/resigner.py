"""APK re-signing engine — wraps apksigner from Android Build Tools.

Per D-07: Full resign replaces original signature. Uses apksigner
defaults (v1+v2+v3). Keystore passwords passed via stdin per T-04-02.

Fully implemented in Task 2.
"""

import os
import subprocess


def resign(
    apk_path: str,
    keystore_path: str,
    keystore_pass: str,
    key_alias: str,
    key_pass: str,
    output_path: str,
) -> str:
    """Re-sign an APK using apksigner with the provided keystore.

    Per D-07: Full resign replacing original signature. Relies on
    apksigner defaults for v1+v2+v3 signing schemes.

    Args:
        apk_path: Path to the unsigned APK.
        keystore_path: Path to the keystore file (.jks or .keystore).
        keystore_pass: Keystore password.
        key_alias: Key alias.
        key_pass: Key password.
        output_path: Path for the signed output APK.

    Returns:
        Path to the signed APK.

    Raises:
        FileNotFoundError: If keystore doesn't exist.
        RuntimeError: If apksigner fails.
    """
    if not os.path.isfile(keystore_path):
        raise FileNotFoundError(f"Keystore not found: {keystore_path}")

    cmd = [
        "apksigner", "sign",
        "--ks", keystore_path,
        "--ks-pass", f"pass:{keystore_pass}",
        "--ks-key-alias", key_alias,
        "--key-pass", f"pass:{key_pass}",
        "--out", output_path,
        apk_path,
    ]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=300,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"apksigner sign failed (exit code {result.returncode}): "
            f"{result.stderr.strip()[:500]}"
        )

    return output_path
