#!/usr/bin/env python3
"""PreToolUse hook for Bash.

Blocks (exit 2) pushes to main, force-pushes, skipping git hooks,
and staging secret files.
"""
import json
import re
import shlex
import sys

data = json.load(sys.stdin)
command = (data.get("tool_input", {}) or {}).get("command") or ""


def block(reason: str) -> None:
    print(f"Blocked by .claude/hooks/guard_bash.py: {reason}", file=sys.stderr)
    sys.exit(2)


FORCE_PUSH = "force-push is not allowed. Push a new commit instead."
PROTECTED_PUSH = (
    "never push to main or develop, and name the branch explicitly: "
    "git push -u origin <type>/<issue>-<slug>, then open a pull request into develop."
)


def shell_source(cmd: str) -> str:
    # Match quoted text, escapes and comments before looking for heredoc openers.
    syntax = re.compile(
        r"""'[^']*'|"(?:\\[\s\S]|[^"\\])*"|\\[\s\S]|(?P<comment>(?<![^\s;&|()<>])#[^\n]*)"""
        r"""|(?<!<)<<(?P<tabs>-)?[ \t]*(?P<quote>['"]?)(?P<word>[\w.-]+)(?P=quote)"""
        r"""(?=$|[\s;&|()<>])|\n"""
    )
    parts = []
    delimiters = []
    end = 0
    while match := syntax.search(cmd, end):
        parts.append(cmd[end:match.start()])
        end = match.end()
        if match["word"]:
            delimiters.append((match["word"], match["tabs"]))
        elif match[0] == "\n":
            parts.append("\n;")  # Keep the boundary after shlex skips the newline.
            for word, strip_tabs in delimiters:
                indent = r"\t*" if strip_tabs else ""
                closing = re.compile(rf"^{indent}{re.escape(word)}(?:\r?\n|$)", re.MULTILINE)
                closing = closing.search(cmd, end)
                end = closing.end() if closing else len(cmd)
            delimiters.clear()
        elif not match["comment"] and match[0] != "\\\n":
            parts.append(match[0])
    parts.append(cmd[end:])
    return "".join(parts)


# ponytail: static checks cannot resolve eval, aliases or pushes built from variables.
def check_pushes(cmd: str) -> None:
    cmd = shell_source(cmd)
    lexer = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError:
        if re.search(r"\bgit\s+push\b", cmd):
            if re.search(r"(--force\b|--force-with-lease\b|\s-f\b|\s\+\S)", cmd):
                block(FORCE_PUSH)
            if (re.search(r"\bgit\s+push\b.*(\s|:)(main|master|develop)(\s|$)", cmd)
                    or re.search(r"\bgit\s+push\s*$", cmd)):
                block(PROTECTED_PUSH)
        return

    groups = [[]]
    for token in tokens:
        if re.fullmatch(r"[;&|()]+", token):
            groups.append([])
        else:
            groups[-1].append(token)

    for group in groups:
        for index, token in enumerate(group):
            name = token.rsplit("/", 1)[-1]
            next_index = index + 1
            if name in ("bash", "sh", "zsh") and index + 2 < len(group) and group[index + 1] == "-c":
                check_pushes(group[index + 2])
            if name != "git":
                continue

            while next_index < len(group):
                option = group[next_index]
                if not re.fullmatch(r"--[\w-]+(?:=[\s\S]*)?|-[A-Za-z]", option):
                    break
                next_index += 2 if option in ("-C", "-c") else 1
            if group[next_index:next_index + 1] != ["push"]:
                continue

            args = group[next_index + 1:]
            if any(
                arg.split("=", 1)[0] in ("--force", "--force-with-lease")
                or re.fullmatch(r"-[A-Za-z]*f[A-Za-z]*", arg)
                or arg.startswith("+")
                for arg in args
            ):
                block(FORCE_PUSH)
            if all(arg.startswith("-") for arg in args) or any(
                arg.rsplit(":", 1)[-1] in ("main", "master", "develop") for arg in args
            ):
                block(PROTECTED_PUSH)


check_pushes(command)

if re.search(r"\bgit\s+(commit|push)\b.*--no-verify", command):
    block("--no-verify skips the repo's checks. Fix the failing check instead.")

if re.search(r"\bgit\s+add\b.*(\.p8|\.p12|\.mobileprovision|\.env\b|diagnostics/)", command):
    block("that file looks like a secret or raw diagnostics. It must not be committed.")

sys.exit(0)
