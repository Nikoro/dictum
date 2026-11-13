import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CommitGateIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.quality = self.root / "scripts/quality"
        self.quality.mkdir(parents=True)
        for name in ("commit_gate.sh", "install_commit_gate.sh", "commit_gate.ref"):
            shutil.copy2(ROOT / "scripts/quality" / name, self.quality / name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def gate(self, *arguments, environment=None):
        (self.root / ".tools").mkdir(exist_ok=True)
        installed = self.root / ".tools/commit_gate"
        if not installed.exists():
            installed.symlink_to(ROOT / ".tools/commit_gate", target_is_directory=True)
        return subprocess.run([str(self.quality / "commit_gate.sh"), *arguments], capture_output=True, text=True, env=environment)

    def test_install_populates_a_fresh_clone_at_the_pinned_revision(self):
        config = self.root / "gitconfig"
        config.write_text(f'[url "{ROOT / ".tools/commit_gate"}"]\n    insteadOf = git@github.com:Nikoro/commit_gate.git\n')
        environment = dict(os.environ, GIT_CONFIG_GLOBAL=str(config))
        result = subprocess.run([str(self.quality / "install_commit_gate.sh")], env=environment,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / ".tools/commit_gate/__main__.py").is_file())
        installed = subprocess.check_output(["git", "-C", str(self.root / ".tools/commit_gate"), "rev-parse", "HEAD"], text=True)
        self.assertEqual(installed.strip(), (self.quality / "commit_gate.ref").read_text().strip())

    def test_working_tree_gate_rejects_prose_comments(self):
        source = self.root / "Example.swift"
        source.write_text("// Compute the width\nlet width = 1\n")
        result = self.gate("check", "Example.swift")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("prose", result.stdout)

    def test_staged_gate_checks_the_index_instead_of_the_working_copy(self):
        source = self.root / "Example.swift"
        source.write_text("// Compute the width\nlet width = 1\n")
        subprocess.run(["git", "-C", str(self.root), "add", "Example.swift"], check=True)
        source.write_text("let width = 1\n")
        result = self.gate("staged", "--offline")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("prose", result.stderr + result.stdout)

    def test_commit_message_requires_note_review_trailers(self):
        source = self.root / "Example.swift"
        source.write_text("// Edge case: older firmware reports zero before its first layout pass\nlet width = 1\n")
        subprocess.run(["git", "-C", str(self.root), "add", "Example.swift"], check=True)
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "-qm", "feat: initial fixture"], check=True)
        source.write_text(source.read_text().replace("width = 1", "width = 2"))
        subprocess.run(["git", "-C", str(self.root), "add", "Example.swift"], check=True)
        message = self.root / "message"
        message.write_text("feat: handle older firmware\n")
        rejected = self.gate("commit-msg", str(message))
        self.assertEqual(rejected.returncode, 1, rejected.stderr)
        self.assertIn("Notes-reviewed", rejected.stdout + rejected.stderr)
        message.write_text("feat: handle older firmware\n\nNotes-reviewed: Example.swift:1\n")
        accepted = self.gate("commit-msg", str(message))
        self.assertEqual(accepted.returncode, 0, accepted.stderr + accepted.stdout)

    def test_alternate_project_index_does_not_affect_the_tool_checkout(self):
        source = self.root / "Example.swift"
        source.write_text("// Compute the width\nlet width = 1\n")
        subprocess.run(["git", "-C", str(self.root), "add", "Example.swift"], check=True)
        alternate = self.root / "alternate-index"
        shutil.copy2(self.root / ".git/index", alternate)
        environment = dict(os.environ, GIT_INDEX_FILE=str(alternate))
        result = self.gate("staged", "--offline", environment=environment)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("fatal:", result.stderr)


if __name__ == "__main__":
    unittest.main()
