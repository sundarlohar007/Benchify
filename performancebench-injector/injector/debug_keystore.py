"""Auto-generate PerformanceBench debug keystore (UNIFIED-SPEC Option A).

Used by the Frida inject path (B-084) so modified APKs are installable on
stock Android devices without requiring the user to supply a keystore.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Tuple


# Spec §18 Step 8 Option A defaults
DEBUG_KEYSTORE_ALIAS = "pb"
DEBUG_KEYSTORE_PASS = "pbdebug"
DEBUG_KEY_PASS = "pbdebug"
DEBUG_DNAME = "CN=PerformanceBench"


def default_debug_keystore_path() -> str:
    """Return path to `pb_debug.keystore` next to the injector package root."""
    root = Path(__file__).resolve().parent.parent
    return str(root / "pb_debug.keystore")


def ensure_debug_keystore(keystore_path: str | None = None) -> Tuple[str, str, str, str]:
    """Ensure a debug keystore exists; generate via keytool if missing.

    Returns:
        (keystore_path, keystore_pass, key_alias, key_pass)

    Raises:
        RuntimeError: if keytool is unavailable or generation fails.
    """
    path = keystore_path or default_debug_keystore_path()
    if os.path.isfile(path):
        return path, DEBUG_KEYSTORE_PASS, DEBUG_KEYSTORE_ALIAS, DEBUG_KEY_PASS

    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    cmd = [
        "keytool",
        "-genkeypair",
        "-v",
        "-keystore", path,
        "-alias", DEBUG_KEYSTORE_ALIAS,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-storepass", DEBUG_KEYSTORE_PASS,
        "-keypass", DEBUG_KEY_PASS,
        "-dname", DEBUG_DNAME,
    ]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except FileNotFoundError as exc:
        raise RuntimeError(
            "keytool not found on PATH. Install a JDK to auto-generate "
            "the PerformanceBench debug keystore, or pass --keystore."
        ) from exc

    if result.returncode != 0:
        raise RuntimeError(
            f"keytool failed to create debug keystore: "
            f"{(result.stderr or result.stdout).strip()[:500]}"
        )

    return path, DEBUG_KEYSTORE_PASS, DEBUG_KEYSTORE_ALIAS, DEBUG_KEY_PASS
