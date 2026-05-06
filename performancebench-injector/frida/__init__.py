"""Frida injection module — gadget injection without APK resigning.

Per D-09: Frida gadget injection for CI/CD. No re-sign needed.
Per D-25: Frida path for CI automation. GUI is desktop-only.

Modules:
    gadget_injector — Pure-Python APK modification (ZIP + .so injection)
    gadget_config_template — JSON config for frida-gadget listen mode
    benchify_frida_agent — JavaScript agent (separate .js file)
"""

from frida.gadget_injector import (
    inject_frida_gadget,
    get_arch_from_apk,
    generate_gadget_config,
    validate_apk_zip,
)

__all__ = [
    "inject_frida_gadget",
    "get_arch_from_apk",
    "generate_gadget_config",
    "validate_apk_zip",
]
