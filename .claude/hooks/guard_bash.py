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


# Check only segments that *run* git push (after optional "(", env/VAR= prefixes and git global
# options), so text that merely mentions a push is not blocked. Cases: test_guard_bash.py.
# ponytail: regex shell split; misses pushes inside `bash -c "..."` or quoted separators. Use shlex if that matters.
for segment in re.split(r"&&|\|\||[;|\n]", command):
    push = re.match(
        r"[\s({]*(?:(?:env|[A-Za-z_]\w*=\S*)\s+)*git\s+"
        r"(?:(?:-[Cc]\s+(?:\"[^\"]*\"|'[^']*'|\S+)"
        r"|--[\w-]+(?:=\S+)?|-(?![Cc])[A-Za-z])\s+)*"
        r"push(?=\s|$)(.*)",
        segment.rstrip(" \t\r)}"),
    )
    if not push:
        continue

    args = push.group(1)
    if re.search(r"(--force\b|--force-with-lease\b|\s-[A-Za-z]*f[A-Za-z]*\b|\s\+\S)", args):
        block("force-push is not allowed. Push a new commit instead.")
    if not args.strip() or re.search(r"[\s:](main|master|develop)(\s|$)", args):
        block("never push to main or develop, and name the branch explicitly: "
              "git push -u origin <type>/<issue>-<slug>, then open a pull request into develop.")

if re.search(r"\bgit\s+(commit|push)\b.*--no-verify", command):
    block("--no-verify skips the repo's checks. Fix the failing check instead.")

if re.search(r"\bgit\s+add\b.*(\.p8|\.p12|\.mobileprovision|\.env\b|diagnostics/)", command):
    block("that file looks like a secret or raw diagnostics. It must not be committed.")

sys.exit(0)
