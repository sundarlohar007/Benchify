"""APK re-signing engine — wraps apksigner from Android Build Tools.

Per D-07: Full resign replaces original signature. Uses apksigner
defaults (v1+v2+v3). Keystore + key passwords are routed via environment
variables (`env:VAR_NAME` apksigner pass spec) so they don't leak through
the process command line (T-04-02 / B-088).

Fully implemented in Task 2.
"""

import os
import subprocess


# Environment variable names that apksigner reads via `env:VAR_NAME`.
_KS_PASS_VAR = "PB_KS_PASS"
_KEY_PASS_VAR = "PB_KEY_PASS"


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

    Per T-04-02 / B-088: passwords are passed via environment variables,
    not via `pass:` literal CLI args. Pre-fix, the literal-args form left
    the keystore + key passwords visible in `ps`/`Procmon` output for any
    user / process on the host while apksigner was running.

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
        "--ks-pass", f"env:{_KS_PASS_VAR}",
        "--ks-key-alias", key_alias,
        "--key-pass", f"env:{_KEY_PASS_VAR}",
        "--out", output_path,
        apk_path,
    ]

    # Inherit the parent env, then layer the password env vars on top.
    # Don't mutate `os.environ` directly — keeps the change scoped to the
    # subprocess and avoids races with concurrent callers.
    env = os.environ.copy()
    env[_KS_PASS_VAR] = keystore_pass
    env[_KEY_PASS_VAR] = key_pass

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=300,
        env=env,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"apksigner sign failed (exit code {result.returncode}): "
            f"{result.stderr.strip()[:500]}"
        )

    return output_path
