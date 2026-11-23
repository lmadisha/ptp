#!/usr/bin/env python3
"""PreToolUse hook for Bash.

Blocks (exit 2) pushes to main, force-pushes, skipping git hooks,
and staging secret files.
"""
import json
import re
import sys

data = json.load(sys.stdin)
command = (data.get("tool_input", {}) or {}).get("command") or ""


def block(reason: str) -> None:
    print(f"Blocked by .claude/hooks/guard_bash.py: {reason}", file=sys.stderr)
    sys.exit(2)


if re.search(r"\bgit\s+push\b", command):
    if re.search(r"(--force\b|--force-with-lease\b|\s-f\b|\s\+\S)", command):
        block("force-push is not allowed. Push a new commit instead.")
    if re.search(r"\bgit\s+push\b.*(\s|:)(main|master)(\s|$)", command) or \
       re.search(r"\bgit\s+push\s*$", command.strip()):
        block("never push to main, and name the branch explicitly: git push -u origin phase-<n>/<topic>, "
              "then open a pull request.")

if re.search(r"\bgit\s+(commit|push)\b.*--no-verify", command):
    block("--no-verify skips the repo's checks. Fix the failing check instead.")

if re.search(r"\bgit\s+add\b.*(\.p8|\.p12|\.mobileprovision|\.env\b|diagnostics/)", command):
    block("that file looks like a secret or raw diagnostics. It must not be committed.")

sys.exit(0)
