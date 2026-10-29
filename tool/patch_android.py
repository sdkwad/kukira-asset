"""Patch the android/ folder that `flutter create` generated in CI.

1. Copy everything from android_overrides/ over android/.
2. Edit app/build.gradle(.kts): minSdk 23, core library desugaring
   (needed by flutter_local_notifications), the Kukira release signing key,
   and no code shrinking for test builds.

The key is never in the repo. CI writes it to android/app/kukira-release.p12
from the KUKIRA_KEYSTORE_B64 secret, and Gradle reads its password from the
KUKIRA_KEYSTORE_PASSWORD environment variable.

Works with both the Groovy and the Kotlin DSL templates.
"""
import pathlib
import re
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
android = root / "android"
overrides = root / "android_overrides"

for src in overrides.rglob("*"):
    if src.is_file():
        dst = android / src.relative_to(overrides)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        print("copied", dst.relative_to(root))

app = android / "app"
kts = (app / "build.gradle.kts").exists()
path = app / ("build.gradle.kts" if kts else "build.gradle")
text = path.read_text()


def sub(pattern, repl, label):
    global text
    new, n = re.subn(pattern, repl, text, count=1)
    if n == 0:
        print(f"patch failed: {label} not found in {path.name}")
        print(text)
        sys.exit(1)
    text = new
    print("patched", label)


sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23", "minSdk")

if kts:
    sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", "desugaring")
    signing = """    signingConfigs {
        create("kukira") {
            storeFile = file("kukira-release.p12")
            storePassword = System.getenv("KUKIRA_KEYSTORE_PASSWORD")
            keyAlias = "kukira"
            keyPassword = System.getenv("KUKIRA_KEYSTORE_PASSWORD")
            storeType = "pkcs12"
        }
    }

    buildTypes {"""
    sub(r"    buildTypes\s*\{", signing, "signingConfigs")
    sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = signingConfigs.getByName("kukira")\n'
        '            isMinifyEnabled = false\n'
        '            isShrinkResources = false',
        "release signing")
    text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n'
else:
    sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", "desugaring")
    signing = """    signingConfigs {
        kukira {
            storeFile file("kukira-release.p12")
            storePassword System.getenv("KUKIRA_KEYSTORE_PASSWORD")
            keyAlias "kukira"
            keyPassword System.getenv("KUKIRA_KEYSTORE_PASSWORD")
            storeType "pkcs12"
        }
    }

    buildTypes {"""
    sub(r"    buildTypes\s*\{", signing, "signingConfigs")
    sub(r"signingConfig\s*=?\s*signingConfigs\.debug",
        "signingConfig = signingConfigs.kukira\n"
        "            minifyEnabled false\n"
        "            shrinkResources false",
        "release signing")
    text += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n    implementation 'androidx.appcompat:appcompat:1.7.0'\n}\n"

path.write_text(text)
print("----", path.name, "----")
print(text)
