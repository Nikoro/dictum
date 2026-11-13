#!/usr/bin/env python3
import argparse
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile


def validate_entitlements(identifier, signed, profile):
    key = "com.apple.security.application-groups"
    group = "group.com.dominikkrajcer.dictum"
    if group not in signed.get(key, []) or group not in profile.get(key, []):
        raise ValueError(f"{identifier}: shared App Group missing from signature or provisioning profile; "
                         "associate the group with both bundle IDs and regenerate their profiles")


def validate_ipa(ipa):
    with tempfile.TemporaryDirectory(prefix="dictum-export-") as directory:
        with zipfile.ZipFile(ipa) as archive:
            archive.extractall(directory)
        app = Path(directory) / "Payload/Dictum.app"
        versions = []
        targets = ((app, "com.dominikkrajcer.dictum"),
                   (app / "PlugIns/DictumKeyboard.appex", "com.dominikkrajcer.dictum.keyboard"))
        for bundle, identifier in targets:
            info = plistlib.loads((bundle / "Info.plist").read_bytes())
            if info["CFBundleIdentifier"] != identifier:
                raise ValueError(f"Unexpected exported bundle identifier: {info['CFBundleIdentifier']}")
            signed = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(bundle)],
                                    check=True, capture_output=True).stdout
            profile = subprocess.run(["security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")],
                                     check=True, capture_output=True).stdout
            validate_entitlements(identifier, plistlib.loads(signed), plistlib.loads(profile)["Entitlements"])
            versions.append((info["CFBundleShortVersionString"], info["CFBundleVersion"]))
        if versions[0] != versions[1]:
            raise ValueError("The app and keyboard must have the same version and build number")
        print(f"Verified Dictum {versions[0][0]} ({versions[0][1]}) and both shared App Group entitlements")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify the exported app and keyboard before TestFlight upload")
    parser.add_argument("ipa", type=Path)
    args = parser.parse_args()
    try:
        validate_ipa(args.ipa)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Export validation failed: {error}\n")
