"""Check the Bash guard using the hook's JSON input protocol."""
import json
import subprocess
import sys

hook = __file__.rsplit("/", 1)[0] + "/guard_bash.py"
cases = [
    ("chmod +x .githooks/pre-push && git push -u origin feat/1-x", 0),
    ("rm -f foo; git push -u origin fix/2-x", 0),
    ("git push -u origin feat/12-main-screen", 0),
    ("gh issue comment 2 --body-file plan.md", 0),
    ("git commit -m 'Document git push --force origin x'", 0),
    ('git commit -m "git push --force is banned"', 0),
    ("cat <<EOF >plan.md\ngit push -f origin x\nEOF\ngh issue comment 2 --body-file plan.md", 0),
    ("cat <<-'PLAN-END'\n\tgit push -f origin x\n\tPLAN-END\ngit push -u origin fix/2-x", 0),
    ("echo git push -f", 2),
    ("git push --follow-tags origin x", 0),
    ("git push --force origin feat/1-x", 2),
    ("git push origin feat/1-#x --force", 2),
    ("git push -f origin feat/1-x", 2),
    ("git push --force-with-lease origin x", 2),
    ("git push origin +feat/1-x", 2),
    ("git push origin main", 2),
    ("git push origin develop", 2),
    ("git push origin master", 2),
    ("git push origin HEAD:main", 2),
    ("git push", 2),
    ("cd repo && git push -f origin x", 2),
    ("(git push -f origin x)", 2),
    ("(git push origin main)", 2),
    ("env A=1 git push -f origin x", 2),
    ("A=1 git push -f origin x", 2),
    ("git -C repo push -f origin x", 2),
    ("git -c core.x=y push origin main", 2),
    ("git push -fu origin x", 2),
    ("git push -uf origin x", 2),
    ("cd repo; git push", 2),
    ("false || git push origin develop", 2),
    ("true | git push origin main", 2),
    ("cd repo\n  git push origin main", 2),
    ("command git push -f origin x", 2),
    ("if true; then git push -f origin x; fi", 2),
    ("for ref in x; do git push -f origin x; done", 2),
    ("exec git push -f origin x", 2),
    ("sudo git push -f origin x", 2),
    ("nohup git push -f origin x", 2),
    ("time git push -f origin x", 2),
    ("! git push -f origin x", 2),
    ("builtin git push -f origin x", 2),
    ("xargs git push -f origin x", 2),
    ("command git push origin main", 2),
    ('bash -c "git push -f origin x"', 2),
    ('sh -c "git push origin HEAD:develop"', 2),
    ('zsh -c "git push -u"', 2),
    ("true & /usr/bin/git --no-pager -p push -u", 2),
    ('git push -f origin x "', 2),
    ("git commit --no-verify -m x", 2),
    ("git add .env", 2),
]

for command, expected in cases:
    result = subprocess.run(
        [sys.executable, hook],
        input=json.dumps({"tool_input": {"command": command}}),
        capture_output=True,
        text=True,
    )
    assert result.returncode == expected, (
        f"{command!r}: expected exit {expected}, got {result.returncode}\n{result.stderr}"
    )
    if expected == 2:
        assert result.stderr.startswith("Blocked by .claude/hooks/guard_bash.py: "), result.stderr

print(f"All {len(cases)} guard_bash cases passed.")
