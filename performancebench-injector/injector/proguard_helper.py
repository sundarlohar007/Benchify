"""ProGuard/R8 mapping.txt parser — resolves obfuscated class/method names.

Per D-05: Full ProGuard/R8 obfuscated builds supported by reading mapping.txt.
"""

import os
import re
from typing import Optional, Dict


def parse_mapping(mapping_path: str) -> Dict[str, str]:
    """Parse a ProGuard mapping.txt file into a class name lookup table.

    Format:
        original.package.OriginalClass -> obfuscated.a.b.Class:
            returnType methodName(params) -> obfName

    Args:
        mapping_path: Path to ProGuard mapping.txt file.

    Returns:
        Dict mapping obfuscated class names to original class names.
    """
    mapping: Dict[str, str] = {}
    current_original = ""
    current_obfuscated = ""

    # Explicit UTF-8 (B-097): mapping.txt may contain non-ASCII source-file
    # paths or comments; default platform encoding (CP-1252 on Windows)
    # raises UnicodeDecodeError on those.
    with open(mapping_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Class mapping: original.package.OriginalClass -> obfuscated.package.Obfuscated:
            class_match = re.match(
                r"^(\S+)\s*->\s*(\S+):?$", line
            )
            if class_match:
                current_original = class_match.group(1)
                current_obfuscated = class_match.group(2).rstrip(":")
                # Store direct mapping
                obfuscated_key = current_obfuscated.replace(".", "/")
                original_value = current_original.replace(".", "/")
                mapping[obfuscated_key] = original_value
                # Also store the obfuscated package prefix for partial matches
                continue

            # Method mapping (skip for now — we only need class resolution)
            # field/method lines are indented and have -> arrow

    return mapping


def resolve_obfuscated_application(
    apk_dir: str,
    mapping_path: Optional[str] = None,
) -> Optional[str]:
    """Resolve the obfuscated Application class name using ProGuard mapping.

    If mapping.txt is provided, parse it to build a lookup table, then
    search smali dirs for a class extending android/app/Application and
    map its obfuscated name back to the original.

    Args:
        apk_dir: Path to the decoded APK directory.
        mapping_path: Optional path to ProGuard mapping.txt.

    Returns:
        The original (de-obfuscated) Application class name, or None if
        not found.
    """
    obfuscation_map = {}
    if mapping_path and os.path.isfile(mapping_path):
        obfuscation_map = parse_mapping(mapping_path)

    # Find all smali directories
    smali_dirs = _find_smali_dirs(apk_dir)
    application_class = None

    for smali_dir in smali_dirs:
        for root, dirs, files in os.walk(smali_dir):
            for f in files:
                if f.endswith(".smali"):
                    filepath = os.path.join(root, f)
                    parent = _get_super_class(filepath)
                    if parent and "android/app/Application" in parent:
                        # Get the obfuscated class name from file
                        class_name = _get_class_name(filepath)
                        if class_name:
                            # Try to de-obfuscate
                            if class_name in obfuscation_map:
                                application_class = obfuscation_map[class_name]
                            else:
                                application_class = class_name
                            return application_class

    return None


def _find_smali_dirs(apk_dir: str) -> list:
    """Find all smali directories in a decoded APK."""
    dirs = []
    for entry in os.listdir(apk_dir):
        entry_path = os.path.join(apk_dir, entry)
        if os.path.isdir(entry_path) and entry.startswith("smali"):
            dirs.append(entry_path)
    return dirs


def _get_super_class(smali_path: str) -> Optional[str]:
    """Extract the super class from a smali file."""
    try:
        with open(smali_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith(".super "):
                    # .super Landroid/app/Application;
                    return line[len(".super "):].rstrip(";").lstrip("L")
    except (OSError, UnicodeDecodeError):
        pass
    return None


def _get_class_name(smali_path: str) -> Optional[str]:
    """Extract the class name from a smali file."""
    try:
        with open(smali_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith(".class "):
                    # .class public La/b/c/MyApp;
                    # or .class public final La/b/c/MyApp;
                    parts = line.split()
                    for part in parts:
                        if part.startswith("L") and part.endswith(";"):
                            return part[1:-1]
    except (OSError, UnicodeDecodeError):
        pass
    return None
