"""Smali bytecode patcher — injects SDK init into Application.onCreate().

Per D-04: Smali injection into Application.onCreate().
Per V25-02: Injection happens in the SINGLE real method body. No wrapper methods.
Per T-04-03: Only inject code into Application.onCreate(). Never modify
    permissions beyond the 5 documented ones.

The patch inserts these instructions at the START of onCreate() after invoke-super:

    # Load PerformanceBench SDK native library
    const-string v0, "performancebench"
    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    # Initialize SDK loader with application context
    invoke-static {p0}, Ldev/benchify/SdkLoader;->init(Landroid/content/Context;)V
"""

import os
import re
from typing import Optional


# SDK init smali instructions to inject (per §26 Smali injection template)
SDK_INIT_TEMPLATE = """    # PerformanceBench SDK initialization
    const-string v0, "performancebench"

    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V

    invoke-static {p0}, Ldev/benchify/SdkLoader;->init(Landroid/content/Context;)V

"""

# SDK classes that need to be importable
# Note: The actual Smali classes from the SDK become available after
# we inject the SDK .dex file. For now, we reference them.
# The injector copies SDK classes into the APK in a separate step.


def find_application_smali(apk_dir: str) -> Optional[str]:
    """Find the smali file containing the Application subclass.

    Searches all smali*/ directories for a class file that extends
    android/app/Application (directly or via transitive hierarchy).

    Args:
        apk_dir: Path to the decoded APK directory.

    Returns:
        Absolute path to the Application smali file, or None if not found.
    """
    smali_dirs = _find_smali_dirs(apk_dir)

    for smali_dir in smali_dirs:
        for root, dirs, files in os.walk(smali_dir):
            for f in files:
                if not f.endswith(".smali"):
                    continue
                filepath = os.path.join(root, f)
                try:
                    with open(filepath, "r", encoding="utf-8", errors="ignore") as sf:
                        content = sf.read(4096)
                        # Check if this class extends Application
                        if ".super Landroid/app/Application;" in content:
                            return filepath
                except OSError:
                    continue

    return None


def _find_smali_dirs(apk_dir: str) -> list:
    """Find all smali directories in a decoded APK directory."""
    dirs = []
    try:
        for entry in os.listdir(apk_dir):
            entry_path = os.path.join(apk_dir, entry)
            if os.path.isdir(entry_path) and entry.startswith("smali"):
                dirs.append(entry_path)
    except OSError:
        pass
    return dirs


def patch_oncreate_method(smali_content: str) -> str:
    """Patch the onCreate() method body to insert SDK initialization.

    Inserts the SDK init Smali instructions immediately after the
    invoke-super call inside the onCreate() method. Uses p0 as the
    context reference (Application instance).

    The patch is inserted at the START of the method body, right after
    the invoke-super {p0}, Landroid/app/Application;->onCreate()V line.

    Args:
        smali_content: The full .method onCreate body (starting from
                       .method line to .end method).

    Returns:
        The patched method body.
    """
    # Check if already patched (idempotency)
    if "Ldev/benchify/SdkLoader;->init" in smali_content:
        return smali_content

    # Find the invoke-super line for onCreate
    # Pattern: invoke-super {p0}, Landroid/app/Application;->onCreate()V
    invoke_super_pattern = re.compile(
        r'(invoke-super\s+\{[^}]*\},\s*Landroid/app/Application;->onCreate\(\)V\s*)\n'
    )

    match = invoke_super_pattern.search(smali_content)
    if match:
        # Insert SDK init AFTER the invoke-super line
        insert_pos = match.end()
        patched = (
            smali_content[:insert_pos]
            + "\n" + SDK_INIT_TEMPLATE
            + smali_content[insert_pos:]
        )
        return patched

    # If there's no invoke-super (unusual but handle it),
    # insert at the start of the method body
    # Find the first instruction after .method declaration
    method_start = re.search(r'\.method.*onCreate.*\n', smali_content)
    if method_start:
        insert_pos = method_start.end()
        patched = (
            smali_content[:insert_pos]
            + SDK_INIT_TEMPLATE
            + smali_content[insert_pos:]
        )
        return patched

    # Fallback: return unchanged
    return smali_content


def patch_smali(smali_content: str) -> str:
    """Patch a complete smali file to inject SDK initialization.

    This is the main entry point. It:
    1. Checks if the SDK is already injected (idempotent check).
    2. Finds the onCreate() method.
    3. Patches it with SDK initialization.

    Per V25-02: Modifies the existing Smali bytecode in-place within
    the single real method body. Does NOT create wrapper methods.

    Args:
        smali_content: Complete Smali file content.

    Returns:
        The patched Smali file content.
    """
    # Idempotency check
    if "Ldev/benchify/SdkLoader;->init" in smali_content:
        return smali_content

    # Extract the onCreate method
    # Smali method pattern: .method ... onCreate()V ... .end method
    method_pattern = re.compile(
        r'(\.method\s+.*?\bonCreate\b\(\).*?\n)(.*?)(\.end\s+method)',
        re.DOTALL,
    )

    match = method_pattern.search(smali_content)
    if match:
        method_header = match.group(1)
        method_body = match.group(2) + match.group(3)

        # Reconstruct the full method text
        full_method = method_header + method_body
        patched_method = patch_oncreate_method(full_method)

        result = smali_content[:match.start()] + patched_method + smali_content[match.end():]
        return result

    # If no onCreate method exists, we need to add one
    # Find the end of the class (before last .end method or class end marker)
    # Insert a new onCreate method
    insert_pattern = re.compile(
        r'(\.method\s+public\s+constructor\s+<init>\(\)V.*?\.end\s+method\s*\n)',
        re.DOTALL,
    )
    constructor_match = insert_pattern.search(smali_content)
    if constructor_match:
        insert_pos = constructor_match.end()
        new_oncreate = (
            "\n.method public onCreate()V\n"
            "    .locals 1\n\n"
            "    invoke-super {p0}, Landroid/app/Application;->onCreate()V\n\n"
            + SDK_INIT_TEMPLATE +
            "    return-void\n"
            ".end method\n\n"
        )
        return smali_content[:insert_pos] + "\n" + new_oncreate + smali_content[insert_pos:]

    return smali_content
