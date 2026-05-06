"""TDD tests for Frida gadget injection — RED phase.

Test 1: gadget_injector.py unpacks APK as ZIP, copies frida-gadget-<arch>.so
        into lib/<abi>/ directory, and re-zips (no re-sign).

Test 2: gadget_config_template.json renders with correct package name and
        listening port substituted.

Test 3: injector_cli.py inject --method frida dispatches without keystore.
"""

import io
import json
import os
import sys
import tempfile
import zipfile
from pathlib import Path

import pytest

# Add injector root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


class TestGadgetInjector:
    """Test suite for frida/gadget_injector.py."""

    def test_inject_frida_gadget_copies_so_into_lib_dir(self, tmp_path):
        """Test 1: gadget_injector copies frida-gadget.so into APK lib/<abi>/."""
        from frida.gadget_injector import inject_frida_gadget

        # Create a mock APK (ZIP) with lib/arm64-v8a/ directory
        apk_path = tmp_path / "test.apk"
        gadget_so_path = tmp_path / "frida-gadget-arm64.so"
        output_path = tmp_path / "out.apk"

        # Write the gadget .so file (dummy content)
        gadget_so_path.write_bytes(b"\x7fELF" + b"\x00" * 1024)

        # Create a mock APK with lib/arm64-v8a/ entry
        with zipfile.ZipFile(apk_path, "w") as zf:
            # Add a directory entry for arm64-v8a
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("lib/arm64-v8a/libnative.so", b"native_code")
            zf.writestr("classes.dex", b"dex_content")
            zf.writestr("AndroidManifest.xml", b"<manifest/>")

        # Inject
        inject_frida_gadget(
            str(apk_path), str(gadget_so_path), str(output_path), arch="arm64"
        )

        # Verify output APK contains gadget
        with zipfile.ZipFile(output_path, "r") as zf:
            names = zf.namelist()
            assert "lib/arm64-v8a/libgadget.so" in names, (
                f"libgadget.so not found in output APK. Contents: {names}"
            )

    def test_get_arch_from_apk_detects_arm64(self, tmp_path):
        """Test: get_arch_from_apk returns 'arm64' when lib/arm64-v8a exists."""
        from frida.gadget_injector import get_arch_from_apk

        apk_path = tmp_path / "test.apk"
        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("lib/arm64-v8a/libfoo.so", b"code")

        assert get_arch_from_apk(str(apk_path)) == "arm64"

    def test_get_arch_from_apk_detects_arm(self, tmp_path):
        """Test: get_arch_from_apk returns 'arm' when only armeabi-v7a exists."""
        from frida.gadget_injector import get_arch_from_apk

        apk_path = tmp_path / "test.apk"
        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/armeabi-v7a/", "")
            zf.writestr("lib/armeabi-v7a/libfoo.so", b"code")

        assert get_arch_from_apk(str(apk_path)) == "arm"

    def test_get_arch_from_apk_prefers_arm64(self, tmp_path):
        """Test: get_arch_from_apk prefers arm64 when both ABIs present."""
        from frida.gadget_injector import get_arch_from_apk

        apk_path = tmp_path / "test.apk"
        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("lib/arm64-v8a/libfoo.so", b"code")
            zf.writestr("lib/armeabi-v7a/", "")
            zf.writestr("lib/armeabi-v7a/libfoo.so", b"code")

        assert get_arch_from_apk(str(apk_path)) == "arm64"

    def test_inject_frida_gadget_embeds_config_json(self, tmp_path):
        """Test 2: gadget config JSON is embedded as libgadget.config.so."""
        from frida.gadget_injector import inject_frida_gadget, generate_gadget_config

        config = generate_gadget_config("com.example.app")
        config_json = json.loads(config)
        assert config_json["interaction"]["type"] == "listen"
        assert config_json["interaction"]["address"] == "127.0.0.1:27042"

        # Verify the config is placed inside the APK
        apk_path = tmp_path / "test.apk"
        gadget_so_path = tmp_path / "frida-gadget-arm64.so"
        output_path = tmp_path / "out.apk"

        gadget_so_path.write_bytes(b"\x7fELF" + b"\x00" * 1024)

        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("classes.dex", b"dex")

        inject_frida_gadget(
            str(apk_path), str(gadget_so_path), str(output_path), arch="arm64"
        )

        with zipfile.ZipFile(output_path, "r") as zf:
            names = zf.namelist()
            assert "lib/arm64-v8a/libgadget.config.so" in names, (
                f"Config not found. Contents: {names}"
            )

    def test_inject_frida_gadget_no_resign(self, tmp_path):
        """Test: Frida injection path does NOT re-sign the APK.

        Signature files (META-INF/) are preserved as-is since we don't modify them.
        """
        from frida.gadget_injector import inject_frida_gadget

        apk_path = tmp_path / "test.apk"
        gadget_so_path = tmp_path / "frida-gadget-arm64.so"
        output_path = tmp_path / "out.apk"

        gadget_so_path.write_bytes(b"\x7fELF" + b"\x00" * 1024)

        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("META-INF/CERT.RSA", b"signature_data")
            zf.writestr("META-INF/CERT.SF", b"sf_data")
            zf.writestr("META-INF/MANIFEST.MF", b"manifest_data")
            zf.writestr("classes.dex", b"dex")

        inject_frida_gadget(
            str(apk_path), str(gadget_so_path), str(output_path), arch="arm64"
        )

        # META-INF files should still exist (no re-sign means they're preserved)
        with zipfile.ZipFile(output_path, "r") as zf:
            names = zf.namelist()
            assert "META-INF/CERT.RSA" in names
            assert "META-INF/MANIFEST.MF" in names

    def test_inject_frida_gadget_invalid_zip_raises(self, tmp_path):
        """Test: Non-ZIP file raises ValueError."""
        from frida.gadget_injector import inject_frida_gadget

        bad_apk = tmp_path / "bad.apk"
        gadget = tmp_path / "gadget.so"
        out = tmp_path / "out.apk"
        bad_apk.write_text("not a zip file")
        gadget.write_bytes(b"\x7fELF" + b"\x00" * 1024)

        with pytest.raises((ValueError, zipfile.BadZipFile)):
            inject_frida_gadget(
                str(bad_apk), str(gadget), str(out), arch="arm64"
            )


class TestFridaInjectorCLI:
    """Test suite for injector/frida_injector.py CLI integration."""

    def test_frida_injector_no_keystore_required(self, tmp_path):
        """Test 3: Frida path does NOT require keystore arguments."""
        from injector.frida_injector import FridaInjector

        apk_path = tmp_path / "test.apk"
        gadget_so_path = tmp_path / "frida-gadget-arm64.so"
        output_path = tmp_path / "out.apk"

        gadget_so_path.write_bytes(b"\x7fELF" + b"\x00" * 1024)

        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("classes.dex", b"dex")

        # FridaInjector should work without keystore
        injector = FridaInjector()
        result = injector.inject(
            apk_path=str(apk_path),
            gadget_so_path=str(gadget_so_path),
            output_path=str(output_path),
        )
        assert result.get("status") == "ok"
        assert os.path.exists(str(output_path))

    def test_frida_injector_returns_verification_steps(self, tmp_path):
        """Test: FridaInjector.inject returns frida-specific verification steps."""
        from injector.frida_injector import FridaInjector

        apk_path = tmp_path / "test.apk"
        gadget_so_path = tmp_path / "frida-gadget-arm64.so"
        output_path = tmp_path / "out.apk"

        gadget_so_path.write_bytes(b"\x7fELF" + b"\x00" * 1024)

        with zipfile.ZipFile(apk_path, "w") as zf:
            zf.writestr("lib/arm64-v8a/", "")
            zf.writestr("classes.dex", b"dex")

        injector = FridaInjector()
        result = injector.inject(
            apk_path=str(apk_path),
            gadget_so_path=str(gadget_so_path),
            output_path=str(output_path),
        )
        # Frida verification is different from Smali (no signing step)
        assert "verification_steps" in result
        steps = result["verification_steps"]
        assert len(steps) >= 2  # At minimum: inject gadget + verify APK installs
        assert any("gadget" in s.lower() for s in steps)


class TestGadgetConfig:
    """Test suite for frida/gadget_config_template.json."""

    def test_config_template_has_listen_interaction(self):
        """Test 2 continued: template JSON has listen type."""
        from frida.gadget_injector import generate_gadget_config

        config = generate_gadget_config()
        parsed = json.loads(config)
        assert parsed["interaction"]["type"] == "listen"
        assert "address" in parsed["interaction"]
        assert "27042" in parsed["interaction"]["address"]
        assert parsed["interaction"]["on_load"] == "resume"

    def test_config_template_substitutes_package(self):
        """Test: generate_gadget_config optionally accepts package name."""
        from frida.gadget_injector import generate_gadget_config

        config = generate_gadget_config("com.example.myapp")
        parsed = json.loads(config)
        assert parsed["interaction"]["type"] == "listen"
