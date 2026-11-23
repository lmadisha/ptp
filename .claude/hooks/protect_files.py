#!/usr/bin/env python3
"""PreToolUse hook for Edit/Write/MultiEdit.

Blocks (exit 2, reason on stderr) when a change would:
  - write secrets or raw diagnostics
  - add network APIs to Swift code (ADR-0002)
  - use private device-lock APIs (ADR-0001)
  - import UI/device frameworks into Packages/PTPCore (AGENTS.md rule 3)
  - put coordinates into trace fixtures (AGENTS.md rule 6)
"""
import json
import re
import sys

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {}) or {}
path = (tool_input.get("file_path") or "").replace("\\", "/")

# Collect the text being written, across Write, Edit and MultiEdit.
parts = [tool_input.get("content") or "", tool_input.get("new_string") or ""]
for edit in tool_input.get("edits") or []:
    parts.append(edit.get("new_string") or "")
text = "\n".join(parts)


def block(reason: str) -> None:
    print(f"Blocked by .claude/hooks/protect_files.py: {reason}", file=sys.stderr)
    sys.exit(2)


SECRET_PATTERNS = (r"\.p8$", r"\.p12$", r"\.cer$", r"\.mobileprovision$",
                   r"\.provisionprofile$", r"(^|/)\.env(\..*)?$")
if any(re.search(p, path) for p in SECRET_PATTERNS):
    block(f"'{path}' looks like a secret or signing file. Never create or edit these in the repo.")

if "/diagnostics/" in path or path.endswith(".diagnostics.csv"):
    block("raw diagnostics can contain real locations and must not be written into the repo. "
          "Anonymise into Packages/PTPCore/Tests/Fixtures/ instead (distances and timestamps only).")

if path.endswith(".swift"):
    network = re.search(r"\b(URLSession|URLRequest|NWConnection|NWListener|NWBrowser)\b", text)
    if network:
        block(f"'{network.group(1)}' adds a network call. PTP has no backend (docs/adr/0002-local-only-data.md). "
              "If this is truly needed, propose a new ADR first.")
    private = re.search(r"GraphicsServices|GSEventLockDevice|SBSSpringBoard|dlopen\(", text)
    if private:
        block(f"'{private.group(0)}' is a private API. PTP never locks the phone itself "
              "(docs/adr/0001-no-programmatic-lock.md); apps using private APIs are rejected by App Review.")
    if "/Packages/PTPCore/Sources/" in path:
        forbidden = re.search(
            r"^\s*import\s+(SwiftUI|UIKit|WatchKit|NearbyInteraction|CoreLocation|WatchConnectivity|ActivityKit)\b",
            text, re.MULTILINE)
        if forbidden:
            block(f"PTPCore must stay pure Swift; it cannot import {forbidden.group(1)}. "
                  "Put device code in the app targets and pass values in.")

if "/Tests/Fixtures/" in path and path.endswith(".csv"):
    if re.search(r"(lat|lon|latitude|longitude)", text, re.IGNORECASE) or \
       re.search(r"-?\d{1,3}\.\d{5,}\s*,\s*-?\d{1,3}\.\d{5,}", text):
        block("trace fixtures must not contain coordinates. Keep only t_ms, distance_m, source, app_state.")

sys.exit(0)
