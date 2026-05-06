"""AndroidManifest.xml patcher — adds SDK permissions, service, and receiver.

Per D-04: Manifest modifications for SDK permissions/services.
Per T-04-03: Additive-only — never remove existing permissions or services.
"""

import re
from lxml import etree
from dataclasses import dataclass
from typing import List


@dataclass
class ManifestPatchResult:
    """Result of manifest patching."""
    success: bool
    patched_xml: str
    added_permissions: List[str]
    added_components: List[str]


# Required permissions for the PerformanceBench SDK
REQUIRED_PERMISSIONS = [
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.INTERNET",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
    "android.permission.POST_NOTIFICATIONS",
]

# SDK components to inject into <application>
# Android namespace for the manifest
ANDROID_NS = "http://schemas.android.com/apk/res/android"

NSMAP = {"android": ANDROID_NS}


def patch_manifest(manifest_xml: str) -> str:
    """Patch an AndroidManifest.xml to add SDK permissions, service, and receiver.

    Modifications (per §24-27):
    1. Add permissions: SYSTEM_ALERT_WINDOW, INTERNET, FOREGROUND_SERVICE,
       FOREGROUND_SERVICE_SPECIAL_USE, POST_NOTIFICATIONS
    2. Add <service> for dev.benchify.BenchifyService inside <application>
    3. Add <receiver> for dev.benchify.BenchifyBroadcastReceiver inside <application>

    All additions are additive only (idempotent — duplicate detection).

    Args:
        manifest_xml: The original AndroidManifest.xml content as string.

    Returns:
        The patched AndroidManifest.xml content as string.
    """
    try:
        # Parse with lxml (preserves XML structure better than minidom)
        parser = etree.XMLParser(remove_blank_text=False)
        root = etree.fromstring(manifest_xml.encode("utf-8"), parser=parser)
    except etree.XMLSyntaxError:
        # Fallback: use string-based patching for malformed XML
        return _patch_manifest_string(manifest_xml)

    existing_perms = _get_existing_permissions(root)
    _add_missing_permissions(root, existing_perms)
    _add_sdk_components(root)

    # Serialize back to string
    result = etree.tostring(
        root,
        encoding="utf-8",
        xml_declaration=True,
        pretty_print=True,
    ).decode("utf-8")

    return result


def _get_existing_permissions(root) -> set:
    """Get names of all permissions already declared in the manifest."""
    existing = set()
    for perm in root.findall("uses-permission"):
        name = perm.get(f"{{{ANDROID_NS}}}name")
        if name:
            existing.add(name)
    return existing


def _add_missing_permissions(root, existing_perms: set):
    """Add missing permissions as <uses-permission> elements before <application>."""
    # Find insertion point — before <application> element
    app_elem = root.find("application")
    if app_elem is None:
        # No application element — add one
        app_elem = etree.SubElement(root, "application")
        app_elem.set(f"{{{ANDROID_NS}}}allowBackup", "true")

    insert_index = list(root).index(app_elem)

    for perm_name in REQUIRED_PERMISSIONS:
        if perm_name not in existing_perms:
            perm_elem = etree.Element("uses-permission")
            perm_elem.set(f"{{{ANDROID_NS}}}name", perm_name)
            root.insert(insert_index, perm_elem)
            insert_index += 1
            existing_perms.add(perm_name)


def _add_sdk_components(root):
    """Add BenchifyService and BenchifyBroadcastReceiver to <application> block."""
    app_elem = root.find("application")
    if app_elem is None:
        app_elem = etree.SubElement(root, "application")

    # Check if service already exists
    ns = f"{{{ANDROID_NS}}}"
    existing_names = set()
    for svc in app_elem.findall("service"):
        name = svc.get(f"{ns}name")
        if name:
            existing_names.add(name)
    for rcv in app_elem.findall("receiver"):
        name = rcv.get(f"{ns}name")
        if name:
            existing_names.add(name)
    for pvd in app_elem.findall("provider"):
        name = pvd.get(f"{ns}name")
        if name:
            existing_names.add(name)

    # Add BenchifyService
    if "dev.benchify.BenchifyService" not in existing_names:
        service = etree.SubElement(app_elem, "service")
        service.set(f"{ns}name", "dev.benchify.BenchifyService")
        service.set(f"{ns}exported", "false")
        service.set(f"{ns}foregroundServiceType", "specialUse")
        existing_names.add("dev.benchify.BenchifyService")

    # Add BenchifyBroadcastReceiver
    if "dev.benchify.BenchifyBroadcastReceiver" not in existing_names:
        receiver = etree.SubElement(app_elem, "receiver")
        receiver.set(f"{ns}name", "dev.benchify.BenchifyBroadcastReceiver")
        receiver.set(f"{ns}exported", "true")
        intent_filter = etree.SubElement(receiver, "intent-filter")
        action = etree.SubElement(intent_filter, "action")
        action.set(f"{ns}name", "com.benchify.COMMAND")
        existing_names.add("dev.benchify.BenchifyBroadcastReceiver")


def _patch_manifest_string(manifest_xml: str) -> str:
    """Fallback string-based manifest patching for malformed XML."""
    result = manifest_xml

    # Check if each permission is already present
    for perm in REQUIRED_PERMISSIONS:
        if perm not in result:
            # Insert before <application> if it exists
            app_match = re.search(r'<application', result)
            if app_match:
                perm_tag = f'\n    <uses-permission android:name="{perm}" />'
                result = result[:app_match.start()] + perm_tag + result[app_match.start():]
            else:
                # Insert at the end of <manifest>
                result = result.replace("</manifest>", f'\n    <uses-permission android:name="{perm}" />\n</manifest>')

    # Add service and receiver if not present
    if "dev.benchify.BenchifyService" not in result:
        service_tag = (
            '\n        <service android:name="dev.benchify.BenchifyService" '
            'android:exported="false" android:foregroundServiceType="specialUse" />'
        )
        app_close = result.rfind("</application>")
        if app_close >= 0:
            result = result[:app_close] + service_tag + "\n    " + result[app_close:]
        else:
            # Create application block
            manifest_close = result.rfind("</manifest>")
            result = (
                result[:manifest_close]
                + '\n    <application android:allowBackup="true">'
                + service_tag
                + '\n    </application>\n'
                + result[manifest_close:]
            )

    if "dev.benchify.BenchifyBroadcastReceiver" not in result:
        receiver_tag = (
            '\n        <receiver android:name="dev.benchify.BenchifyBroadcastReceiver" '
            'android:exported="true">'
            '\n            <intent-filter>'
            '\n                <action android:name="com.benchify.COMMAND" />'
            '\n            </intent-filter>'
            '\n        </receiver>'
        )
        app_close = result.rfind("</application>")
        if app_close >= 0:
            result = result[:app_close] + receiver_tag + "\n    " + result[app_close:]

    return result
