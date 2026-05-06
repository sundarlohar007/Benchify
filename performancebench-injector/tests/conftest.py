"""Pytest fixtures for performancebench-injector tests."""

import os
import pytest
import tempfile
import shutil
from pathlib import Path


@pytest.fixture
def temp_dir():
    """Create a temporary directory that is cleaned up after test."""
    d = tempfile.mkdtemp(prefix="pb_injector_test_")
    yield d
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture
def sample_apk_dir(temp_dir):
    """Create a mock decoded APK directory structure with smali files."""
    # Create smali directory
    smali_dir = os.path.join(temp_dir, "smali", "com", "example", "testapp")
    os.makedirs(smali_dir, exist_ok=True)

    # Create a mock Application subclass with onCreate
    smali_content = """.class public Lcom/example/testapp/MyApplication;
.super Landroid/app/Application;
.source "MyApplication.java"


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/app/Application;-><init>()V

    return-void
.end method

.method public onCreate()V
    .locals 0

    invoke-super {p0}, Landroid/app/Application;->onCreate()V

    # Some app initialization
    invoke-static {}, Lcom/example/testapp/SomeHelper;->init()V

    return-void
.end method

.method public onTerminate()V
    .locals 0

    invoke-super {p0}, Landroid/app/Application;->onTerminate()V

    return-void
.end method
"""
    with open(os.path.join(smali_dir, "MyApplication.smali"), "w") as f:
        f.write(smali_content)

    # Create AndroidManifest.xml
    manifest_content = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp"
    android:versionCode="1"
    android:versionName="1.0">

    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="34"/>

    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:name="com.example.testapp.MyApplication"
        android:allowBackup="true"
        android:label="Test App">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>

</manifest>
"""
    with open(os.path.join(temp_dir, "AndroidManifest.xml"), "w") as f:
        f.write(manifest_content)

    # Create apktool.yml
    apktool_yml = """version: 2.9.3
apkFileName: test.apk
isFrameworkApk: false
usesFramework:
  ids: 1
sdkInfo:
  minSdkVersion: '21'
  targetSdkVersion: '34'
packageInfo:
  forcedPackageId: '127'
versionInfo:
  versionCode: '1'
  versionName: '1.0'
sharedLibrary: false
sparseResources: false
doNotCompress:
- resources.arsc
"""
    with open(os.path.join(temp_dir, "apktool.yml"), "w") as f:
        f.write(apktool_yml)

    return temp_dir


@pytest.fixture
def sample_proguard_mapping(temp_dir):
    """Create a mock ProGuard mapping.txt file."""
    mapping_content = """com.example.testapp.MyApplication -> a.b.c.MyApp:
    void onCreate() -> a
    void onTerminate() -> b
com.example.testapp.SomeHelper -> x.y.z.Hlp:
    void init() -> i
"""
    mapping_path = os.path.join(temp_dir, "mapping.txt")
    with open(mapping_path, "w") as f:
        f.write(mapping_content)
    return mapping_path


@pytest.fixture
def obfuscated_apk_dir(temp_dir, sample_proguard_mapping):
    """Create a mock decoded APK with ProGuard-obfuscated Application class."""
    smali_dir = os.path.join(temp_dir, "smali", "a", "b", "c")
    os.makedirs(smali_dir, exist_ok=True)

    # Obfuscated Application class
    smali_content = """.class public La/b/c/MyApp;
.super Landroid/app/Application;
.source "MyApp.java"


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/app/Application;-><init>()V

    return-void
.end method

.method public a()V
    .locals 0

    invoke-super {p0}, Landroid/app/Application;->onCreate()V

    invoke-static {}, Lx/y/z/Hlp;->i()V

    return-void
.end method
"""
    with open(os.path.join(smali_dir, "MyApp.smali"), "w") as f:
        f.write(smali_content)

    # Rewrite mapping.txt with a slightly different format (more realistic)
    mapping_path = os.path.join(temp_dir, "mapping.txt")
    with open(mapping_path, "w") as f:
        f.write("""com.example.testapp.MyApplication -> a.b.c.MyApp:
    void onCreate() -> a
    void onTerminate() -> b
com.example.testapp.SomeHelper -> x.y.z.Hlp:
    void init() -> i
""")

    # Create minimal manifest
    manifest = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testapp"
    android:versionCode="1"
    android:versionName="1.0">
    <application android:name="a.b.c.MyApp" android:allowBackup="true">
        <activity android:name=".MainActivity" android:exported="true"/>
    </application>
</manifest>
"""
    with open(os.path.join(temp_dir, "AndroidManifest.xml"), "w") as f:
        f.write(manifest)

    return temp_dir


@pytest.fixture
def smali_dir_no_application(temp_dir):
    """Create a mock decoded APK with no Application subclass (uses default)."""
    smali_dir = os.path.join(temp_dir, "smali", "com", "example", "noapp")
    os.makedirs(smali_dir, exist_ok=True)

    # Just an Activity, no Application
    smali_content = """.class public Lcom/example/noapp/MainActivity;
.super Landroid/app/Activity;
.source "MainActivity.java"

.method public onCreate(Landroid/os/Bundle;)V
    .locals 1

    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    return-void
.end method
"""
    with open(os.path.join(smali_dir, "MainActivity.smali"), "w") as f:
        f.write(smali_content)

    return temp_dir
