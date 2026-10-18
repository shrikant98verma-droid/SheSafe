#!/usr/bin/env python3
"""Patches a freshly created Flutter project (`flutter create`) so SheSafe builds.

Usage: python3 tools/prepare_android.py <flutter_project_dir>

It adds the Android permissions, lock-screen flags, minSdk 23 and core library
desugaring. If android/app/google-services.json exists it also turns on the
Firebase (Google services) Gradle plugin.
"""
import os
import re
import sys

root = sys.argv[1]
android = os.path.join(root, 'android')
app = os.path.join(android, 'app')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def find(folder, base):
    for ext in ('.kts', ''):
        p = os.path.join(folder, base + ext)
        if os.path.exists(p):
            return p, ext == '.kts'
    raise SystemExit(f'{base}(.kts) not found in {folder}')


# ---- AndroidManifest.xml -----------------------------------------------------
manifest = os.path.join(app, 'src', 'main', 'AndroidManifest.xml')
m = read(manifest)
if 'USE_FULL_SCREEN_INTENT' not in m:
    block = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    <queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
    </queries>
"""
    m = m.replace('<application', block + '    <application', 1)
    m = re.sub(
        r'(<activity\s+android:name="\.MainActivity")',
        r'\1\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"',
        m,
        count=1,
    )
    m = m.replace('android:label="shesafe"', 'android:label="SheSafe"')
    write(manifest, m)

# ---- app/build.gradle(.kts) --------------------------------------------------
gradle, kts = find(app, 'build.gradle')
g = read(gradle)

g = re.sub(r'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion',
           'minSdk = 23' if kts else 'minSdkVersion 23', g)

if 'esugaring' not in g:
    flag = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
    g = re.sub(r'(compileOptions\s*\{)', r'\1\n        ' + flag, g, count=1)
    dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
           if kts else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
    if re.search(r'^dependencies\s*\{', g, re.M):
        g = re.sub(r'^(dependencies\s*\{)', r'\1\n    ' + dep, g, count=1, flags=re.M)
    else:
        g += '\ndependencies {\n    ' + dep + '\n}\n'

has_firebase = os.path.exists(os.path.join(app, 'google-services.json'))
if has_firebase and 'google-services' not in g:
    plugin = 'id("com.google.gms.google-services")' if kts else 'id "com.google.gms.google-services"'
    g = re.sub(r'(id\(?\s*"dev\.flutter\.flutter-gradle-plugin"\s*\)?)',
               r'\1\n    ' + plugin, g, count=1)
write(gradle, g)

# ---- settings.gradle(.kts): declare the Google services plugin ----------------
if has_firebase:
    settings, kts_s = find(android, 'settings.gradle')
    s = read(settings)
    if 'google-services' not in s:
        if kts_s:
            s = re.sub(r'(id\("com\.android\.application"\)\s*version\s*"[^"]+"\s*apply\s*false)',
                       r'\1\n    id("com.google.gms.google-services") version "4.4.2" apply false',
                       s, count=1)
        else:
            s = re.sub(r'(id\s+"com\.android\.application"\s*version\s*"[^"]+"\s*apply\s*false)',
                       r'\1\n    id "com.google.gms.google-services" version "4.4.2" apply false',
                       s, count=1)
        write(settings, s)

print('Android project patched.' + (' Firebase plugin enabled.' if has_firebase else ' (no google-services.json: demo mode build)'))
