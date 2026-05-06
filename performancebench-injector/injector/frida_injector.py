"""Frida injector — integrates Frida gadget injection with the CLI.

Per D-09, D-25: Frida path is the CI/CD path. No keystore required.
Does NOT call smali_patcher, manifest_patcher, or resigner.

Threat T-04-13: User accepts no-signature tradeoff per D-09.
"""

import json
import os
from typing import Dict, Any, Optional

from frida.gadget_injector import (
    inject_frida_gadget,
    get_arch_from_apk,
    generate_gadget_config,
    validate_apk_zip,
)


class FridaInjector:
    """Handles Frida gadget injection workflow.

    Unlike SmaliInjector, this path:
    - Does NOT require keystore
    - Does NOT call apktool (uses ZIP manipulation)
    - Does NOT re-sign the APK
    - Does NOT modify Smali or Manifest
    """

    def inject(
        self,
        apk_path: str,
        gadget_so_path: str,
        output_path: str = "injected.apk",
        arch: Optional[str] = None,
        config_json: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Run the Frida gadget injection pipeline.

        Steps:
        1. Validate APK
        2. Detect architecture
        3. Inject frida-gadget.so + config
        4. Return result with verification steps

        Args:
            apk_path: Path to input APK.
            gadget_so_path: Path to frida-gadget-<arch>.so file.
            output_path: Output APK path.
            arch: Target architecture (auto-detected if None).
            config_json: Custom gadget config (generated if None).

        Returns:
            Dict with status, output_path, detected_arch, and verification_steps.
        """
        result: Dict[str, Any] = {}

        try:
            # Step 1: Validate APK
            validate_apk_zip(apk_path)

            # Step 2: Detect architecture
            detected_arch = arch or get_arch_from_apk(apk_path)
            result["detected_arch"] = detected_arch

            # Step 3: Inject gadget
            output = inject_frida_gadget(
                apk_path=apk_path,
                gadget_so_path=gadget_so_path,
                output_path=output_path,
                arch=detected_arch,
                config_json=config_json,
            )

            result["status"] = "ok"
            result["output_path"] = output
            result["method"] = "frida"

            # Frida-specific verification steps (no signing needed)
            result["verification_steps"] = [
                "Inject frida-gadget.so — gadget embedded in APK lib directory",
                "Verify APK installs — install and launch on device with frida-server running",
                "Connect desktop — frida-server on device forwards metrics to desktop",
            ]

        except Exception as e:
            result["status"] = "error"
            result["error"] = str(e)

        return result

    @staticmethod
    def get_cli_args_description() -> str:
        """Return help text for Frida-specific CLI arguments."""
        return (
            "Frida gadget injection — no re-sign needed, embeds frida-gadget.so "
            "directly into the APK's native library directory. Requires frida-server "
            "running on the target device. This is the recommended path for CI/CD."
        )
