import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PATCH_SCRIPT = PROJECT_ROOT / "android_overlay" / "patch_build_gradle.py"


def _run_patch(tmp_path: Path, filename: str, source: str) -> str:
    gradle_file = tmp_path / filename
    gradle_file.write_text(source, encoding="utf-8")
    subprocess.run(
        [sys.executable, str(PATCH_SCRIPT), str(gradle_file)],
        check=True,
        capture_output=True,
        text=True,
    )
    return gradle_file.read_text(encoding="utf-8")


def test_kotlin_gradle_patch_is_applied_and_idempotent(tmp_path):
    source = '''plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.app"
    defaultConfig {
        minSdk = flutter.minSdkVersion
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
'''
    patched = _run_patch(tmp_path, "build.gradle.kts", source)
    assert "minSdk = 24" in patched
    assert "val cobraKeystoreProperties" in patched
    assert 'signingConfigs.getByName("release")' in patched
    assert "tesseract4android" in patched

    file_path = tmp_path / "build.gradle.kts"
    first = file_path.read_text(encoding="utf-8")
    subprocess.run(
        [sys.executable, str(PATCH_SCRIPT), str(file_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    assert file_path.read_text(encoding="utf-8") == first


def test_groovy_gradle_patch_uses_groovy_syntax_and_is_idempotent(tmp_path):
    source = '''plugins {
    id 'com.android.application'
}

android {
    namespace 'com.example.app'
    defaultConfig {
        minSdkVersion flutter.minSdkVersion
    }
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
'''
    patched = _run_patch(tmp_path, "build.gradle", source)
    assert "minSdkVersion 24" in patched
    assert "def cobraKeystoreProperties" in patched
    assert "val cobraKeystoreProperties" not in patched
    assert "storeFile = file(cobraKeystoreProperties['storeFile'])" in patched
    assert "signingConfig (cobraKeystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug)" in patched
    assert "tesseract4android" in patched

    file_path = tmp_path / "build.gradle"
    first = file_path.read_text(encoding="utf-8")
    subprocess.run(
        [sys.executable, str(PATCH_SCRIPT), str(file_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    assert file_path.read_text(encoding="utf-8") == first
