#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

raise SystemExit(subprocess.run([str(Path(__file__).with_name("commit_gate.sh")), "check", *sys.argv[1:]]).returncode)
