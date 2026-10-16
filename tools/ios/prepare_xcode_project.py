#!/usr/bin/env python3
"""Configure a generated Flutter Runner for App Store distribution.

No certificate or private key material is committed. The GitHub Actions
workflow supplies an Apple distribution profile from repository secrets.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import re

BUNDLE_ID = "jp.cloxs.kotohogu"
PROJECT = Path("ios/Runner.xcodeproj/project.pbxproj")
INFO_PLIST = Path("ios/Runner/Info.plist")


def prepare(profile_path: Path, export_options_path: Path) -> None:
    profile = plistlib.loads(profile_path.read_bytes())
    team_ids = profile.get("TeamIdentifier")
    if not isinstance(team_ids, list) or len(team_ids) != 1:
        raise ValueError("Distribution profile must identify exactly one Apple team")
    team = team_ids[0]
    if not isinstance(team, str) or not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Invalid Apple Team ID in provisioning profile")
    if profile.get("Entitlements", {}).get("application-identifier") != f"{team}.{BUNDLE_ID}":
        raise ValueError(f"Provisioning profile does not match {BUNDLE_ID}")
    if profile.get("Entitlements", {}).get("get-task-allow") is not False:
        raise ValueError("An App Store distribution profile is required (not development)")
    if "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices"):
        raise ValueError("Do not use an ad-hoc or enterprise provisioning profile")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime):
        raise ValueError("Provisioning profile has no expiration date")
    if expiry.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        raise ValueError("Provisioning profile has expired")
    name = profile.get("Name")
    if not isinstance(name, str) or not name:
        raise ValueError("Provisioning profile has no name")

    project = PROJECT.read_text(encoding="utf-8")
    bundle_pattern = re.compile(
        r"(?m)^(?P<indent>[ \t]*)PRODUCT_BUNDLE_IDENTIFIER = (?P<value>[^;]+);$"
    )
    runner_count = 0
    test_count = 0

    def replace_bundle(match: re.Match[str]) -> str:
        nonlocal runner_count, test_count
        indent = match.group("indent")
        current = match.group("value").strip('"')
        if current.endswith(".RunnerTests"):
            test_count += 1
            return f"{indent}PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.RunnerTests;"
        runner_count += 1
        return "\n".join(
            [
                f"{indent}PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
                f"{indent}DEVELOPMENT_TEAM = {team};",
                f"{indent}CODE_SIGN_STYLE = Manual;",
                f"{indent}CODE_SIGN_IDENTITY = \"Apple Distribution\";",
                f"{indent}PROVISIONING_PROFILE_SPECIFIER = {json.dumps(name, ensure_ascii=False)};",
            ]
        )

    configured = bundle_pattern.sub(replace_bundle, project)
    if runner_count != 3 or test_count != 3:
        raise ValueError(
            "Expected the fresh Flutter iOS Runner Xcode template "
            f"(found {runner_count} Runner and {test_count} test bundle IDs). "
            "Regenerate ios/ or update the signing configuration explicitly."
        )
    PROJECT.write_text(configured, encoding="utf-8")

    info = plistlib.loads(INFO_PLIST.read_bytes())
    info["CFBundleDisplayName"] = "ことほぐ"
    INFO_PLIST.write_bytes(plistlib.dumps(info))

    export_options = {
        "method": "app-store-connect",
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "teamID": team,
        "provisioningProfiles": {BUNDLE_ID: name},
        "manageAppVersionAndBuildNumber": False,
    }
    export_options_path.write_bytes(plistlib.dumps(export_options))
    print(f"Configured iOS Bundle ID {BUNDLE_ID} for App Store distribution")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile-plist", required=True, type=Path)
    parser.add_argument("--export-options", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.profile_plist, args.export_options)
