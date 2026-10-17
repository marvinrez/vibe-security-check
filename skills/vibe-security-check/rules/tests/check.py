#!/usr/bin/env python3
"""Check every Semgrep rule against the fixtures, line by line.

In a vulnerable fixture, a comment carrying "ruleid: <id>" says the line below it
must produce a finding from that rule, and every finding must be on a line
annotated that way. A safe fixture must produce no finding at all. Every rule in
the file has to be annotated somewhere, so a rule added without a fixture fails.

Semgrep's default ignore list skips directories named tests/, so each fixture
is scanned as a file.

Usage: python3 rules/tests/check.py      (from skills/vibe-security-check)
"""
import json
import pathlib
import re
import subprocess
import sys

RULES = pathlib.Path("rules/vibe-security.yaml")
FIXTURES = pathlib.Path("rules/tests")
ANNOTATION = re.compile(r"(?://|#)\s*ruleid:\s*([\w\s,-]+?)\s*$")

defined = set(re.findall(r"^  - id: (\S+)", RULES.read_text(), re.M))


def findings(path):
    out = subprocess.run(
        ["semgrep", "--config", str(RULES), "--metrics=off", "--disable-version-check",
         "--no-git-ignore", "--quiet", "--json", str(path)],
        capture_output=True, text=True,
    )
    result = json.loads(out.stdout)
    if result["errors"]:
        sys.exit(f"{path}: semgrep reported errors: {result['errors']}")
    return {(r["start"]["line"], r["check_id"].split(".")[-1]) for r in result["results"]}


def annotated(path):
    expected = set()
    for number, line in enumerate(path.read_text().splitlines(), start=1):
        match = ANNOTATION.search(line)
        if match:
            for rule in re.split(r"[\s,]+", match.group(1)):
                expected.add((number + 1, rule))
    return expected


problems = []
covered = set()
vulnerable = sorted(FIXTURES.glob("vulnerable.*"))
safe = sorted(FIXTURES.glob("safe.*"))

for path in vulnerable:
    got, want = findings(path), annotated(path)
    covered |= {rule for _, rule in want}
    problems += [f"{path}:{line}: expected {rule}, which did not fire" for line, rule in sorted(want - got)]
    problems += [f"{path}:{line}: {rule} fired on a line not annotated for it" for line, rule in sorted(got - want)]

for path in safe:
    problems += [f"{path}:{line}: {rule} fired on a safe fixture" for line, rule in sorted(findings(path))]

problems += [f"annotation names a rule not in {RULES}: {rule}" for rule in sorted(covered - defined)]
problems += [f"rule with no vulnerable fixture: {rule}" for rule in sorted(defined - covered)]

if problems:
    print("\n".join(problems))
    sys.exit(1)
lines = sum(len(annotated(p)) for p in vulnerable)
print(f"ok: all {len(defined)} rules pinned on {lines} annotated lines, "
      f"0 findings on {len(safe)} safe fixtures")
