import importlib.util
from datetime import date
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
script = Path(__file__).resolve().parents[2] / "scripts/version.py"
spec = importlib.util.spec_from_file_location("dictum_version", script)
version = importlib.util.module_from_spec(spec)
spec.loader.exec_module(version)


class VersionTests(unittest.TestCase):
    def test_export_rejects_silently_removed_app_group(self):
        validation_spec = importlib.util.spec_from_file_location(
            "dictum_export", script.with_name("validate-ios-export.py"))
        validation = importlib.util.module_from_spec(validation_spec)
        validation_spec.loader.exec_module(validation)
        key = "com.apple.security.application-groups"
        group = "group.com.dominikkrajcer.dictum"
        validation.validate_entitlements("Dictum", {key: [group]}, {key: [group]})
        for signed, profile in (({}, {key: []}), ({key: [group]}, {key: []}),
                                ({}, {key: [group]})):
            with self.subTest(signed=signed, profile=profile), self.assertRaises(ValueError):
                validation.validate_entitlements("Dictum", signed, profile)

    def test_migrates_legacy_counter(self):
        self.assertEqual(version.next_build(1, date(2026, 11, 12)), 26111201)

    def test_increments_same_day(self):
        self.assertEqual(version.next_build(26111201, date(2026, 11, 12)), 26111202)

    def test_resets_on_next_day_and_year(self):
        self.assertEqual(version.next_build(26111299, date(2026, 11, 13)), 26111301)
        self.assertEqual(version.next_build(26123199, date(2027, 1, 1)), 27010101)

    def test_rejects_overflow_without_carrying_into_tomorrow(self):
        with self.assertRaises(ValueError):
            version.next_build(26111299, date(2026, 11, 12))

    def test_rejects_clock_rollback(self):
        with self.assertRaises(ValueError):
            version.next_build(26111301, date(2026, 11, 12))

    def test_core_semver_bumps(self):
        self.assertEqual(version.semantic_version("0.10.3", "patch"), "0.10.4")
        self.assertEqual(version.semantic_version("0.10.3", "minor"), "0.11.0")
        self.assertEqual(version.semantic_version("0.10.3", "major"), "1.0.0")
        for invalid in ("01.2.3", "1.2", "1.2.3.4", "1.2.3-beta", "1.2.3+42"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                version.semantic_version(invalid)

    def test_preparation_persists_one_version_for_all_targets(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / "project.yml"
            project.write_text('settings:\n  base:\n    MARKETING_VERSION: "0.10.3"\n'
                               '    CURRENT_PROJECT_VERSION: "1"\ntargets:\n  Dictum: {}\n')
            self.assertEqual(version.prepare(project, date(2026, 11, 12), bump="minor"),
                             ("0.11.0", 26111201))
            self.assertEqual(version.prepare(project, date(2026, 11, 12)),
                             ("0.11.0", 26111202))

    def test_failed_preparation_does_not_modify_project(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / "project.yml"
            original = ('settings:\n  base:\n    MARKETING_VERSION: "0.10.3"\n'
                        '    CURRENT_PROJECT_VERSION: "26111299"\n')
            project.write_text(original)
            with self.assertRaises(ValueError):
                version.prepare(project, date(2026, 11, 12), bump="minor")
            self.assertEqual(project.read_text(), original)

    def test_testflight_script_handles_empty_options_on_macos_bash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "iOS/Resources").mkdir(parents=True)
            (root / "scripts").mkdir()
            shutil.copy(script.parents[1] / "iOS/Resources/TestFlightExportOptions.plist",
                        root / "iOS/Resources/TestFlightExportOptions.plist")
            (root / "scripts/version.py").write_text("print('Version prepared')\n")
            (root / "scripts/validate-ios-export.py").write_text("print('Export verified')\n")
            for command, body in (("git", f"echo '{root}'"), ("xcodegen", "exit 0"),
                                  ("xcodebuild", "exit 0")):
                stub = root / command
                stub.write_text("#!/bin/sh\n" + body + "\n")
                stub.chmod(0o755)
            environment = {key: value for key, value in os.environ.items()
                           if not key.startswith("DICTUM_ASC_")}
            environment["PATH"] = str(root) + ":/usr/bin:/bin"
            result = subprocess.run(["/bin/bash", str(script.with_name("ios-testflight.sh"))],
                                    env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
