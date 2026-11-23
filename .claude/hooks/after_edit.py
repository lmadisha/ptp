#!/usr/bin/env python3
"""PostToolUse hook for Edit/Write/MultiEdit.

- Formats the edited Swift file with swift-format, if installed (silent).
- After a detection change, reminds Claude to replay traces (exit 2 shows
  the message to Claude; PostToolUse cannot undo the edit).
"""
import json
import shutil
import subprocess
import sys

data = json.load(sys.stdin)
path = ((data.get("tool_input", {}) or {}).get("file_path") or "").replace("\\", "/")

if not path.endswith(".swift"):
    sys.exit(0)

if shutil.which("swift-format"):
    subprocess.run(["swift-format", "format", "-i", path],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

DETECTION_FILES = ("DetectionEngine", "PTPStateMachine", "DetectionConfig")
if "/Packages/PTPCore/Sources/" in path and any(name in path for name in DETECTION_FILES):
    print("Detection logic changed. Run /replay-traces before finishing, and report each trace's "
          "expected vs actual result.", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
