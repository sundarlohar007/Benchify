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

# Matches any .super that ends with Application; (Application, MultiDexApplication, custom)
_APPLICATION_SUPER_RE = re.compile(r"\.super\s+L[^;]+Application;")


def _application_class_from_manifest(apk_dir: str) -> Optional[str]:
    """Read AndroidManifest.xml application android:name → relative smali path."""
    manifest_path = os.path.join(apk_dir, "AndroidManifest.xml")
    if not os.path.isfile(manifest_path):
        return None
    try:
        with open(manifest_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except OSError:
        return None

    app_match = re.search(
        r"<application\b[^>]*\bandroid:name\s*=\s*\"([^\"]+)\"",
        content,
        re.DOTALL | re.IGNORECASE,
    )
    if not app_match:
        return None

    name = app_match.group(1).strip()
    if not name:
        return None

    if name.startswith("."):
        pkg_match = re.search(r"\bpackage\s*=\s*\"([^\"]+)\"", content)
        if not pkg_match:
            return None
        name = pkg_match.group(1) + name

    return name.replace(".", "/") + ".smali"


def find_application_smali(apk_dir: str) -> Optional[str]:
    """Find the smali file containing the Application subclass.

    Prefers the class named in AndroidManifest.xml ``android:name`` on
    ``<application>``. Falls back to scanning smali*/ for classes that
    extend Application, MultiDexApplication, or any type ending in
    ``Application;``.

    Args:
        apk_dir: Path to the decoded APK directory.

    Returns:
        Absolute path to the Application smali file, or None if not found.
    """
    smali_dirs = _find_smali_dirs(apk_dir)

    # Prefer manifest-declared Application class
    rel_smali = _application_class_from_manifest(apk_dir)
    if rel_smali:
        for smali_dir in smali_dirs:
            candidate = os.path.join(smali_dir, rel_smali)
            if os.path.isfile(candidate):
                return candidate

    for smali_dir in smali_dirs:
        for root, dirs, files in os.walk(smali_dir):
            for f in files:
                if not f.endswith(".smali"):
                    continue
                filepath = os.path.join(root, f)
                try:
                    with open(filepath, "r", encoding="utf-8", errors="ignore") as sf:
                        content = sf.read(4096)
                        if (
                            ".super Landroid/app/Application;" in content
                            or ".super Landroidx/multidex/MultiDexApplication;" in content
                            or _APPLICATION_SUPER_RE.search(content)
                        ):
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


def _ensure_v0_register(smali_content: str, before_pos: int) -> str:
    """Bump .locals / .registers so at least one local (v0) exists.

    B-086: SDK_INIT_TEMPLATE uses v0. Application.onCreate has 1 param (p0).
    - .locals N with N < 1 → .locals 1
    - .registers N (total including params): need N-1 >= 1 i.e. N >= 2;
      if N < 2, bump to 2.

    Uses the nearest directive before ``before_pos`` (the onCreate body).
    """
    prefix = smali_content[:before_pos]

    locals_matches = list(re.finditer(r"\.locals\s+(\d+)", prefix))
    if locals_matches:
        m = locals_matches[-1]
        n = int(m.group(1))
        if n < 1:
            return smali_content[: m.start(1)] + "1" + smali_content[m.end(1) :]
        return smali_content

    registers_matches = list(re.finditer(r"\.registers\s+(\d+)", prefix))
    if registers_matches:
        m = registers_matches[-1]
        n = int(m.group(1))
        if n < 2:
            return smali_content[: m.start(1)] + "2" + smali_content[m.end(1) :]
    return smali_content


def _extract_super_type(smali_content: str) -> str:
    """Return the class's .super type descriptor, or Application as default."""
    m = re.search(r"\.super\s+(L[^;]+;)", smali_content)
    if m:
        return m.group(1)
    return "Landroid/app/Application;"


def patch_oncreate_method(smali_content: str) -> str:
    """Patch the onCreate() method body to insert SDK initialization.

    Inserts the SDK init Smali instructions immediately after the
    invoke-super call inside the onCreate() method. Uses p0 as the
    context reference (Application instance).

    The original invoke-super line is kept as-is (any superclass).
    Before inserting, bumps .locals/.registers so v0 is valid (B-086).

    Args:
        smali_content: The full .method onCreate body (starting from
                       .method line to .end method).

    Returns:
        The patched method body.
    """
    # Check if already patched (idempotency)
    if "Ldev/benchify/SdkLoader;->init" in smali_content:
        return smali_content

    # B-087: match ANY superclass invoke-super for onCreate()V
    invoke_super_pattern = re.compile(
        r"(invoke-super\s+\{[^}]*\},\s*L[^;]+;->onCreate\(\)V\s*)\n"
    )

    match = invoke_super_pattern.search(smali_content)
    if match:
        # B-086: ensure v0 exists before inserting SDK init
        smali_content = _ensure_v0_register(smali_content, match.start())
        # Re-find after possible rewrite (digit length usually unchanged)
        match = invoke_super_pattern.search(smali_content)
        insert_pos = match.end()
        # Keep original invoke-super line as-is; insert SDK init AFTER it
        patched = (
            smali_content[:insert_pos]
            + "\n" + SDK_INIT_TEMPLATE
            + smali_content[insert_pos:]
        )
        return patched

    # If there's no invoke-super (unusual but handle it),
    # insert at the start of the method body
    method_start = re.search(r"\.method.*onCreate.*\n", smali_content)
    if method_start:
        smali_content = _ensure_v0_register(smali_content, method_start.end())
        method_start = re.search(r"\.method.*onCreate.*\n", smali_content)
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
        r"(\.method\s+.*?\bonCreate\b\(\).*?\n)(.*?)(\.end\s+method)",
        re.DOTALL,
    )

    match = method_pattern.search(smali_content)
    if match:
        method_header = match.group(1)
        method_body = match.group(2) + match.group(3)

        # Reconstruct the full method text
        full_method = method_header + method_body
        patched_method = patch_oncreate_method(full_method)

        result = smali_content[: match.start()] + patched_method + smali_content[match.end() :]
        return result

    # If no onCreate method exists, synthesize one using the real .super type (B-087)
    insert_pattern = re.compile(
        r"(\.method\s+public\s+constructor\s+<init>\(\)V.*?\.end\s+method\s*\n)",
        re.DOTALL,
    )
    constructor_match = insert_pattern.search(smali_content)
    if constructor_match:
        insert_pos = constructor_match.end()
        super_type = _extract_super_type(smali_content)
        new_oncreate = (
            "\n.method public onCreate()V\n"
            "    .locals 1\n\n"
            f"    invoke-super {{p0}}, {super_type}->onCreate()V\n\n"
            + SDK_INIT_TEMPLATE
            + "    return-void\n"
            ".end method\n\n"
        )
        return smali_content[:insert_pos] + "\n" + new_oncreate + smali_content[insert_pos:]

    return smali_content
