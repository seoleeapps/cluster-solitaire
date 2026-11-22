#!/usr/bin/env python3
"""서명한 iOS App Store IPA를 만들고 Apple 심사 필수 항목을 검사한다.

    python3 tools/export_ios.py
    python3 tools/export_ios.py --project-only

순서: 네이티브 설정 검사(check_native), AdMob iOS 래퍼 설치(install_admob),
서비스 값 주입(prepare_services --platform ios), Godot iOS Xcode 프로젝트 내보내기,
주입한 값 지우기(restore), xcodebuild archive/exportArchive, 결과 IPA 검사.
"""
import argparse
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

import check_native
import install_admob
import prepare_services

ROOT = Path(__file__).resolve().parents[1]
APP_STORE_CONFIG = ROOT / "app-store/app-store.config.json"


def run(command, timeout, env, secrets, cwd=ROOT):
    """명령을 실행하고 비밀값을 가린 출력을 보여 준다."""
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
    log = result.stdout + result.stderr
    visible = log
    for value in secrets:
        if value:
            visible = visible.replace(value, "[redacted]")
    if visible:
        print(visible, end="" if visible.endswith("\n") else "\n")
    clean = re.sub(r"\x1b\[[0-9;]*m", "", log)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {Path(command[0]).name}")
    if Path(command[0]).name == "godot" and re.search(r"^(?:SCRIPT ERROR|ERROR:)", clean, re.M):
        raise RuntimeError("Godot reported an error during iOS export")
    return clean


def verify_ipa(ipa_path, cfg, ios_app_id):
    """IPA의 Info.plist, PrivacyInfo.xcprivacy, 서명·아이콘·비추적 기준을 점검한다."""
    errors = []
    with zipfile.ZipFile(ipa_path) as z:
        names = z.namelist()
        app_dirs = sorted({n.split("/")[1] for n in names if n.startswith("Payload/") and n.count("/") >= 2 and n.split("/")[1].endswith(".app")})
        if len(app_dirs) != 1:
            return [f"Expected 1 .app bundle in Payload/, found: {app_dirs}"], {}
        app_prefix = f"Payload/{app_dirs[0]}/"
        plist_name = app_prefix + "Info.plist"
        if plist_name not in names:
            return ["Missing Info.plist in .app"], {}
        plist = plistlib.loads(z.read(plist_name))
        privacy_name = app_prefix + "PrivacyInfo.xcprivacy"
        privacy = plistlib.loads(z.read(privacy_name)) if privacy_name in names else {}
        pck_name = next((n for n in names if n.startswith(app_prefix) and n.endswith(".pck")), "")
        pck_has_services = b"data/services/release.json" in z.read(pck_name) if pck_name else False

    bundle_id = cfg["bundleId"]
    if plist.get("CFBundleIdentifier") != bundle_id:
        errors.append(f"CFBundleIdentifier mismatch: {plist.get('CFBundleIdentifier')} != {bundle_id}")
    if plist.get("CFBundleShortVersionString") != str(cfg["version"]):
        errors.append(f"CFBundleShortVersionString mismatch: {plist.get('CFBundleShortVersionString')}")
    if plist.get("CFBundleVersion") != str(cfg["buildNumber"]):
        errors.append(f"CFBundleVersion mismatch: {plist.get('CFBundleVersion')}")
    if plist.get("GADApplicationIdentifier") != ios_app_id:
        errors.append(f"GADApplicationIdentifier missing or wrong: {plist.get('GADApplicationIdentifier')}")
    if plist.get("ITSAppUsesNonExemptEncryption") is not False:
        errors.append(f"ITSAppUsesNonExemptEncryption must be False, got {plist.get('ITSAppUsesNonExemptEncryption')}")
    if "NSUserTrackingUsageDescription" in plist:
        errors.append("No-ATT app must not declare NSUserTrackingUsageDescription in Info.plist")
    if privacy and privacy.get("NSPrivacyTracking") is not False:
        errors.append(f"NSPrivacyTracking must be False, got {privacy.get('NSPrivacyTracking')}")
    if not pck_has_services:
        errors.append("Embedded release.json service values missing in .pck")

    summary = {
        "ipa": str(ipa_path.relative_to(ROOT)),
        "bytes": ipa_path.stat().st_size,
        "bundleId": plist.get("CFBundleIdentifier"),
        "version": plist.get("CFBundleShortVersionString"),
        "build": plist.get("CFBundleVersion"),
        "deviceFamily": plist.get("UIDeviceFamily"),
        "nonExemptEncryption": plist.get("ITSAppUsesNonExemptEncryption"),
        "hasAttKey": "NSUserTrackingUsageDescription" in plist,
        "privacyTracking": privacy.get("NSPrivacyTracking") if privacy else None,
        "admobAppId": "app-specific" if plist.get("GADApplicationIdentifier") == ios_app_id else "mismatch",
        "serviceValuesInPck": pck_has_services,
    }
    return errors, summary


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project-only", action="store_true", help="Xcode 프로젝트 생성까지만 실행")
    args = parser.parse_args()

    errors = check_native.validate(ROOT)
    if errors:
        raise ValueError("\n".join(errors))

    cfg = json.loads(APP_STORE_CONFIG.read_text(encoding="utf-8"))
    ios_dir = ROOT / "build/ios"
    if ios_dir.exists():
        shutil.rmtree(ios_dir)
    ios_dir.mkdir(parents=True, exist_ok=True)
    proj_path = ios_dir / "FourAlike.xcodeproj"

    install_admob.install("ios")
    values = prepare_services.collect(os.environ, Path.home(), platform="ios")
    secrets = [v for v in values.values() if isinstance(v, str) and not v.startswith("https://")]
    secrets += [v for k, v in os.environ.items() if v and any(w in k.upper() for w in ("PASSWORD", "TOKEN", "PRIVATE_KEY", "SECRET"))]
    env = dict(os.environ)
    godot = os.environ.get("GODOT", "godot")
    project = ROOT / prepare_services.PROJECT_FILE
    original = project.read_bytes()

    try:
        prepare_services.inject(ROOT, values, platform="ios")
        run([godot, "--headless", "--path", str(ROOT / "godot"), "--import", "--quit-after", "2"], 300, env, secrets)
        run([godot, "--headless", "--path", str(ROOT / "godot"), "--export-release", "iOS", str(proj_path)], 1200, env, secrets)
    finally:
        prepare_services.restore(ROOT)
        project.write_bytes(original)

    if not proj_path.is_dir():
        raise RuntimeError(f"Missing generated Xcode project: {proj_path}")
    print("Xcode project generated:", proj_path.relative_to(ROOT))
    if args.project_only:
        return

    scheme = proj_path.stem
    archive_path = ios_dir / "FourAlike.xcarchive"
    ipa_dir = ios_dir / "ipa"
    export_plist = ios_dir / "ExportOptions.plist"
    export_plist.write_bytes(plistlib.dumps({
        "method": "app-store-connect",
        "teamID": cfg["teamId"],
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {cfg["bundleId"]: cfg["provisioningProfile"]},
        "stripSwiftSymbols": True,
        "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
    }))

    run([
        "xcodebuild",
        "-project", str(proj_path),
        "-scheme", scheme,
        "-configuration", "Release",
        "-destination", "generic/platform=iOS",
        "-archivePath", str(archive_path),
        "CODE_SIGN_STYLE=Manual",
        f"DEVELOPMENT_TEAM={cfg['teamId']}",
        "CODE_SIGN_IDENTITY=Apple Distribution",
        f"PROVISIONING_PROFILE_SPECIFIER={cfg['provisioningProfile']}",
        "archive",
    ], 1800, env, secrets)

    run([
        "xcodebuild",
        "-exportArchive",
        "-archivePath", str(archive_path),
        "-exportPath", str(ipa_dir),
        "-exportOptionsPlist", str(export_plist),
    ], 900, env, secrets)

    ipas = sorted(ipa_dir.glob("*.ipa"))
    if not ipas:
        raise RuntimeError(f"No .ipa created in {ipa_dir}")
    ipa_path = ipas[0]
    target_ipa = ios_dir / "FourAlike.ipa"
    if ipa_path != target_ipa:
        shutil.copy2(ipa_path, target_ipa)
    else:
        target_ipa = ipa_path

    ipa_errors, summary = verify_ipa(target_ipa, cfg, values["ADMOB_APP_ID"])
    print(json.dumps({"ok": not ipa_errors, "errors": ipa_errors, **summary}, ensure_ascii=False, indent=2))
    if ipa_errors:
        raise RuntimeError("IPA verification failed")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
