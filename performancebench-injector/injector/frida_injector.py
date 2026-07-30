"""Frida injector — integrates Frida gadget injection with the CLI.

Per D-09 / D-25 Frida remains the lighter CI path (no apktool / smali).
B-084: modifying the ZIP invalidates the original signature, so we always
re-sign with an auto-generated (or user-provided) debug keystore so the
output APK installs on stock Android devices.
"""

from __future__ import annotations

import os
import tempfile
from typing import Any, Dict, Optional

from frida.gadget_injector import (
    inject_frida_gadget,
    get_arch_from_apk,
    generate_gadget_config,
    validate_apk_zip,
)
from injector.debug_keystore import ensure_debug_keystore
from injector.resigner import resign


class FridaInjector:
    """Handles Frida gadget injection + debug re-sign workflow.

    Unlike SmaliInjector, this path:
    - Does NOT call apktool / smali_patcher / manifest_patcher
    - Does NOT require a user keystore (auto-generates pb_debug.keystore)
    - DOES re-sign so the APK is installable (B-084)
    """

    def inject(
        self,
        apk_path: str,
        gadget_so_path: str,
        output_path: str = "injected.apk",
        arch: Optional[str] = None,
        config_json: Optional[str] = None,
        keystore_path: Optional[str] = None,
        keystore_pass: Optional[str] = None,
        key_alias: Optional[str] = None,
        key_pass: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Run the Frida gadget injection pipeline.

        Steps:
        1. Validate APK
        2. Detect architecture
        3. Inject frida-gadget.so + config
        4. Re-sign with debug (or user) keystore
        5. Return result with verification steps
        """
        result: Dict[str, Any] = {}
        unsigned_path: Optional[str] = None

        try:
            validate_apk_zip(apk_path)

            detected_arch = arch or get_arch_from_apk(apk_path)
            result["detected_arch"] = detected_arch

            # Write unsigned ZIP to a temp file, then resign into output_path
            fd, unsigned_path = tempfile.mkstemp(suffix="-frida-unsigned.apk")
            os.close(fd)

            inject_frida_gadget(
                apk_path=apk_path,
                gadget_so_path=gadget_so_path,
                output_path=unsigned_path,
                arch=detected_arch,
                config_json=config_json,
            )

            if keystore_path:
                ks_path = keystore_path
                ks_pass = keystore_pass or ""
                alias = key_alias or "pb"
                k_pass = key_pass or ks_pass
            else:
                ks_path, ks_pass, alias, k_pass = ensure_debug_keystore()

            resign(
                apk_path=unsigned_path,
                keystore_path=ks_path,
                keystore_pass=ks_pass,
                key_alias=alias,
                key_pass=k_pass,
                output_path=output_path,
            )

            result["status"] = "ok"
            result["output_path"] = output_path
            result["method"] = "frida"
            result["signed"] = True
            result["keystore"] = ks_path
            result["verification_steps"] = [
                "Inject frida-gadget.so — gadget embedded in APK lib directory",
                "Re-sign with debug keystore — APK installable on stock Android",
                "Verify APK installs — adb install -r -d <output.apk>",
                "Connect desktop — frida-gadget listens; metrics stream to desktop",
            ]

        except Exception as e:
            result["status"] = "error"
            result["error"] = str(e)

        finally:
            if unsigned_path and os.path.exists(unsigned_path):
                try:
                    os.remove(unsigned_path)
                except OSError:
                    pass

        return result

    @staticmethod
    def get_cli_args_description() -> str:
        """Return help text for Frida-specific CLI arguments."""
        return (
            "Frida gadget injection — embeds frida-gadget.so into the APK's "
            "native library directory, then re-signs with an auto-generated "
            "debug keystore (or --keystore if provided) so the APK installs "
            "on stock Android. Recommended path for CI/CD."
        )
