#!/usr/bin/env python3
"""Stop hook.

If anything under Packages/PTPCore changed (vs HEAD, including untracked
files), run the PTPCore tests before Claude finishes. On failure, exit 2 so
Claude keeps working and sees the failing output.

Skips when: Claude is already continuing because of this hook
(stop_hook_active), the package doesn't exist yet, or `swift` isn't installed.
"""
import json
import os
import shutil
import subprocess
import sys

data = json.load(sys.stdin)
if data.get("stop_hook_active"):
    sys.exit(0)  # avoid an endless test-fix loop; one forced retry per stop

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or "."
package = os.path.join(root, "Packages", "PTPCore")
if not os.path.isdir(package) or not shutil.which("swift"):
    sys.exit(0)


def git(*args: str) -> str:
    result = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, check=False)
    return result.stdout


changed = git("diff", "--name-only", "HEAD", "--", "Packages/PTPCore")
untracked = git("ls-files", "--others", "--exclude-standard", "--", "Packages/PTPCore")
if not (changed.strip() or untracked.strip()):
    sys.exit(0)

result = subprocess.run(["swift", "test", "--package-path", package],
                        capture_output=True, text=True, check=False)
if result.returncode != 0:
    tail = "\n".join((result.stdout + result.stderr).splitlines()[-40:])
    print("PTPCore tests are failing. Fix them before finishing:\n" + tail, file=sys.stderr)
    sys.exit(2)

sys.exit(0)
