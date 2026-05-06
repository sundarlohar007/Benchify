"""Pure-Python Frida gadget injection into APK files.

Per D-09, D-25: Frida gadget injection does NOT require APK decompile/recompile/re-sign.
It injects frida-gadget-<arch>.so into the APK's native lib directory
and embeds a JSON configuration alongside it.

This uses Python's zipfile module exclusively — no apktool, no shell commands.

Threat T-04-13: Frida gadget injection leaves original signature intact.
User accepts this tradeoff per D-09.
"""

import json
import os
import shutil
import tempfile
import zipfile
from typing import Optional, Dict, List

# Known Android ABIs in priority order
ANDROID_ABIS = ["arm64-v8a", "armeabi-v7a", "x86_64", "x86"]

# Canonical frida-gadget .so naming per ABI
ARCH_TO_SO_NAME = {
    "arm64": "frida-gadget-arm64.so",
    "arm": "frida-gadget-arm.so",
    "x86_64": "frida-gadget-x86_64.so",
    "x86": "frida-gadget-x86.so",
}

# ABI directory mapping for APK lib/ structure
ARCH_TO_ABI = {
    "arm64": "arm64-v8a",
    "arm": "armeabi-v7a",
    "x86_64": "x86_64",
    "x86": "x86",
}


def validate_apk_zip(apk_path: str) -> bool:
    """Validate that a file is a valid APK (valid ZIP file).

    Args:
        apk_path: Path to the APK file.

    Returns:
        True if valid.

    Raises:
        ValueError: If the file is not a valid ZIP/APK.
    """
    if not os.path.isfile(apk_path):
        raise ValueError(f"APK file not found: {apk_path}")

    try:
        with zipfile.ZipFile(apk_path, "r") as zf:
            bad = zf.testzip()
            if bad is not None:
                raise ValueError(f"APK contains corrupt entry: {bad}")
    except zipfile.BadZipFile as e:
        raise ValueError(f"File is not a valid ZIP/APK: {apk_path}: {e}")

    return True


def get_arch_from_apk(apk_path: str) -> str:
    """Detect target architecture from APK lib/ directory contents.

    Scans the ZIP for lib/<abi>/ directories and returns the best-match
    architecture string. Prefers arm64 over arm when both present.

    Args:
        apk_path: Path to the APK file.

    Returns:
        Architecture string: 'arm64', 'arm', 'x86_64', or 'x86'.

    Raises:
        ValueError: If no recognized lib directory is found.
    """
    validate_apk_zip(apk_path)

    lib_dirs: Dict[str, bool] = {}

    with zipfile.ZipFile(apk_path, "r") as zf:
        for name in zf.namelist():
            # Match lib/<abi>/ pattern
            parts = name.split("/")
            if len(parts) >= 2 and parts[0] == "lib":
                abi = parts[1]
                if abi in ANDROID_ABIS:
                    lib_dirs[abi] = True

    # Prefer arm64-v8a
    if "arm64-v8a" in lib_dirs:
        return "arm64"
    elif "armeabi-v7a" in lib_dirs:
        return "arm"
    elif "x86_64" in lib_dirs:
        return "x86_64"
    elif "x86" in lib_dirs:
        return "x86"
    else:
        # Fallback: if lib/ exists but no recognized ABI, default to arm64
        # Many modern APKs only target arm64
        raise ValueError(
            f"No recognized ABI directory found in APK lib/. "
            f"Expected one of: {ANDROID_ABIS}"
        )


def generate_gadget_config(package_name: Optional[str] = None) -> str:
    """Generate the frida-gadget JSON configuration.

    Uses listen mode on 127.0.0.1:27042 with on_load=resume.
    The package_name param is accepted for future extension but not
    currently used in the config (frida-gadget doesn't need it).

    Returns:
        JSON string suitable for writing as libgadget.config.so.
    """
    config = {
        "interaction": {
            "type": "listen",
            "address": "127.0.0.1:27042",
            "on_load": "resume",
        }
    }
    return json.dumps(config, indent=2)


def inject_frida_gadget(
    apk_path: str,
    gadget_so_path: str,
    output_path: str,
    arch: Optional[str] = None,
    config_json: Optional[str] = None,
) -> str:
    """Inject frida-gadget.so into the APK's native lib directory.

    Performs these steps:
    1. Open APK as ZIP file and validate it.
    2. Detect target architecture (or use provided arch).
    3. Copy frida-gadget-<arch>.so into lib/<abi>/libgadget.so.
    4. If APK already has lib/<abi>/libgadget.so, overwrite it.
    5. Embed gadget config as lib/<abi>/libgadget.config.so.
    6. Write modified ZIP to output_path.
    7. Does NOT sign the APK (original signature preserved).

    Args:
        apk_path: Path to the input APK file.
        gadget_so_path: Path to the frida-gadget-<arch>.so file.
        output_path: Path where the modified APK will be written.
        arch: Architecture override (auto-detected if None).
        config_json: Custom gadget config JSON (generated if None).

    Returns:
        The output_path on success.

    Raises:
        ValueError: If APK is invalid or arch detection fails.
        OSError: If file I/O fails.
    """
    # Validate inputs
    validate_apk_zip(apk_path)

    if not os.path.isfile(gadget_so_path):
        raise ValueError(f"Gadget .so file not found: {gadget_so_path}")

    # Detect architecture
    if arch is None:
        arch = get_arch_from_apk(apk_path)

    abi_dir = ARCH_TO_ABI.get(arch)
    if abi_dir is None:
        raise ValueError(f"Unknown architecture: {arch}. Expected one of: {list(ARCH_TO_ABI.keys())}")

    libgadget_path = f"lib/{abi_dir}/libgadget.so"
    libconfig_path = f"lib/{abi_dir}/libgadget.config.so"

    # Read the gadget .so binary
    with open(gadget_so_path, "rb") as f:
        gadget_so_data = f.read()

    if len(gadget_so_data) < 4:
        raise ValueError(f"Gadget .so file is too small: {gadget_so_path}")

    # Generate (or use provided) config
    if config_json is None:
        config_json = generate_gadget_config()

    # Copy APK to a temporary file, modify, then move to output
    # This avoids corrupting the input if something fails
    tmp_output = output_path + ".tmp"

    try:
        with zipfile.ZipFile(apk_path, "r") as zin:
            with zipfile.ZipFile(tmp_output, "w", zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    # Skip if we're going to overwrite this entry
                    if item.filename == libgadget_path:
                        continue
                    if item.filename == libconfig_path:
                        continue

                    # Copy all other entries as-is
                    data = zin.read(item.filename)
                    zout.writestr(item, data)

                # Ensure the lib/<abi>/ directory entry exists
                abi_dir_entry = f"lib/{abi_dir}/"
                zout.writestr(zipfile.ZipInfo(abi_dir_entry), b"")

                # Inject the gadget .so
                zout.writestr(libgadget_path, gadget_so_data)

                # Inject the config
                config_bytes = config_json.encode("utf-8")
                zout.writestr(libconfig_path, config_bytes)

        # Move temp to final output
        if os.path.exists(output_path):
            os.remove(output_path)
        shutil.move(tmp_output, output_path)

    except Exception:
        # Clean up temp file on failure
        if os.path.exists(tmp_output):
            os.remove(tmp_output)
        raise

    return output_path
