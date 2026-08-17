#!/usr/bin/env python3
"""Integrity checks for the package itself. No model, no network, no dependencies.

The skill demands that every layer carry a decision and every mandatory control
carry an acceptance check. This applies the same rule to the package that says
it: the release stamp agrees in all four places, the two READMEs stay mirrors,
every path a document points at exists, every layer playbook ends in a check
that can be run, and every layer has an eval case or the suite is lying about
its coverage.

    python evals/validate.py
    python evals/validate.py --quiet

Exit code 0 when everything holds, 1 when it does not.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EVALS = ROOT / "evals"

TEXT_SUFFIXES = {
    ".md", ".py", ".sql", ".sh", ".yml", ".yaml", ".ts", ".tsx", ".js", ".jsx",
    ".json", ".conf", ".txt", ".example",
}
TEXT_NAMES = {"Dockerfile", "LICENSE", ".gitignore"}
SKIP_DIRS = {".git", "docs", "results", "__pycache__", "node_modules"}

# The Portuguese README is the one document that carries accented text.
NON_ASCII_ALLOWED = {"README.pt-BR.md"}

LAYERS = 14  # thirteen core layers plus the conditional AI surface

problems: list[str] = []
notes: list[str] = []


def fail(check: str, detail: str) -> None:
    problems.append(f"{check}: {detail}")


def text_files() -> list[pathlib.Path]:
    found = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if path.suffix in TEXT_SUFFIXES or path.name in TEXT_NAMES:
            found.append(path)
    return sorted(found)


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def check_version_stamp() -> None:
    skill = read(ROOT / "SKILL.md")
    match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$", skill, re.M)
    if not match:
        fail("version", "SKILL.md has no version field in its frontmatter")
        return
    declared = match.group(1)

    changelog = read(ROOT / "CHANGELOG.md")
    released = re.findall(r"^## \[([0-9]+\.[0-9]+\.[0-9]+)\]", changelog, re.M)
    if not released:
        fail("version", "CHANGELOG.md has no released entry")
    elif released[0] != declared:
        fail("version", f"SKILL.md says {declared}, the newest CHANGELOG entry says {released[0]}")

    if re.search(r"^## \[Unreleased\]", changelog, re.M):
        notes.append("CHANGELOG has an Unreleased section: content is ahead of the stamped version")

    # Both READMEs stamp the version in two places each, a badge and a line of
    # text, and the Portuguese one does it in Portuguese.
    stamp = re.compile(r"(?i)vers\w*[^\w]{0,6}([0-9]+\.[0-9]+\.[0-9]+)")
    for name in ("README.md", "README.pt-BR.md"):
        found = set(stamp.findall(read(ROOT / name)))
        if not found:
            fail("version", f"{name} shows no version stamp")
        elif found != {declared}:
            fail("version", f"{name} shows {sorted(found)}, SKILL.md says {declared}")

    check_date_stamp()


def check_date_stamp() -> None:
    """The header carries the same day in the badge and in the text, in both languages."""
    iso = re.compile(r"\b(\d{4})-{1,2}(\d{2})-{1,2}(\d{2})\b")
    brazilian = re.compile(r"\b(\d{2})[-/]{1,2}(\d{2})[-/]{1,2}(\d{4})\b")
    days = {}
    for name in ("README.md", "README.pt-BR.md"):
        header = "\n".join(read(ROOT / name).splitlines()[:30])
        found = {(y, m, d) for y, m, d in iso.findall(header)}
        found |= {(y, m, d) for d, m, y in brazilian.findall(header)}
        if not found:
            fail("version", f"{name} shows no update date in its header")
        elif len(found) > 1:
            fail("version", f"{name} shows more than one update date: {sorted(found)}")
        else:
            days[name] = found.pop()
    if len(set(days.values())) > 1:
        fail("version", f"the two READMEs carry different update dates: {days}")


def check_readme_mirror() -> None:
    en = re.findall(r"^## (.+)$", read(ROOT / "README.md"), re.M)
    pt = re.findall(r"^## (.+)$", read(ROOT / "README.pt-BR.md"), re.M)
    if len(en) != len(pt):
        fail("mirror", f"README.md has {len(en)} sections, README.pt-BR.md has {len(pt)}")


def check_typography_and_encoding() -> None:
    for path in text_files():
        rel = path.relative_to(ROOT).as_posix()
        body = read(path)
        for line_no, line in enumerate(body.splitlines(), 1):
            # Built with chr() so this file stays clean under its own rule.
            if any(ord(c) in (0x2014, 0x2013) for c in line):
                fail("typography", f"{rel}:{line_no} contains a long dash, which this package does not use")
            if path.name not in NON_ASCII_ALLOWED:
                for char in line:
                    if ord(char) > 127:
                        fail("encoding", f"{rel}:{line_no} contains non-ASCII {char!r} (U+{ord(char):04X})")
                        break


def check_links() -> None:
    known = {p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*") if p.is_file()}
    known |= {p.relative_to(ROOT).as_posix() + "/" for p in ROOT.rglob("*") if p.is_dir()}

    link = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
    # Prose names package paths from the root, because that is where the agent
    # reads them from, so those are resolved from the root and not from the
    # file that mentions them.
    bare = re.compile(r"(?<![\w/`.-])((?:references|templates|assets|evals|docs)/[\w./-]+)")

    def exists(candidate: pathlib.Path) -> bool:
        try:
            as_rel = candidate.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            return False
        return as_rel in known or as_rel + "/" in known

    for path in ROOT.rglob("*.md"):
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        rel = path.relative_to(ROOT).as_posix()
        body = read(path)
        targets = {(t, "link") for t in link.findall(body)}
        targets |= {(t, "bare") for t in bare.findall(body)}
        for target, kind in targets:
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            cleaned = target.split("#")[0].strip().rstrip(".,;:)")
            if not cleaned:
                continue
            if kind == "bare":
                ok = exists(ROOT / cleaned)
            else:
                ok = exists(path.parent / cleaned) or exists(ROOT / cleaned)
            if not ok:
                fail("links", f"{rel} points at a path that does not exist: {target}")


def check_playbook_coverage() -> None:
    body = read(ROOT / "references" / "layer-playbooks.md")
    sections = re.split(r"^## (\d+)\. (.+)$", body, flags=re.M)
    # split yields [preamble, number, title, content, number, title, content, ...]
    pairs = [(int(sections[i]), sections[i + 1], sections[i + 2]) for i in range(1, len(sections), 3)]
    if len(pairs) != 13:
        fail("playbooks", f"expected 13 numbered layer sections, found {len(pairs)}")
    for number, title, content in pairs:
        if "**Acceptance check." not in content:
            fail("playbooks", f"layer {number} ({title.strip()}) has no acceptance check")
    numbers = [n for n, _, _ in pairs]
    if numbers != sorted(numbers) or len(set(numbers)) != len(numbers):
        fail("playbooks", f"layer numbering is not a clean sequence: {numbers}")


def check_eval_cases() -> None:
    case_files = sorted((EVALS / "cases").glob("*/case.json"))
    if not case_files:
        fail("evals", "no cases found")
        return

    covered: dict[int, list[str]] = {}
    for case_file in case_files:
        meta = json.loads(read(case_file))
        case_id = meta.get("id", case_file.parent.name)
        if case_id != case_file.parent.name:
            fail("evals", f"{case_id} does not match its directory name {case_file.parent.name}")
        for key in ("id", "title", "layer", "layer_name", "fixture", "signature", "why"):
            if key not in meta:
                fail("evals", f"{case_id} is missing '{key}'")
        for pattern in meta.get("signature", []):
            try:
                re.compile(pattern)
            except re.error as exc:
                fail("evals", f"{case_id} has an invalid signature: {exc}")
        if not meta.get("signature"):
            fail("evals", f"{case_id} has no signature, so nothing can be scored")

        fixture = meta.get("fixture", "")
        vulnerable = case_file.parent / "vulnerable" / fixture
        fixed = case_file.parent / "fixed" / fixture
        for path, label in ((vulnerable, "vulnerable"), (fixed, "fixed")):
            if not path.is_file():
                fail("evals", f"{case_id} is missing {label}/{fixture}")
        if vulnerable.is_file() and fixed.is_file() and vulnerable.read_bytes() == fixed.read_bytes():
            fail("evals", f"{case_id} has identical variants, so the pair proves nothing")

        layer = meta.get("layer")
        if isinstance(layer, int):
            covered.setdefault(layer, []).append(case_id)

    for layer in range(1, LAYERS + 1):
        if layer not in covered:
            fail("evals", f"layer {layer} has no case: the suite has a blank cell")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--quiet", action="store_true", help="print only failures")
    args = parser.parse_args()

    checks = (
        ("release stamp agrees in all four places", check_version_stamp),
        ("the two READMEs are mirrors", check_readme_mirror),
        ("typography and encoding", check_typography_and_encoding),
        ("every path pointed at exists", check_links),
        ("every layer playbook ends in a check", check_playbook_coverage),
        ("every layer has an eval case", check_eval_cases),
    )

    for label, function in checks:
        before = len(problems)
        function()
        if not args.quiet:
            status = "ok" if len(problems) == before else "FAIL"
            print(f"  [{status:>4}] {label}")

    if not args.quiet:
        for note in notes:
            print(f"\nnote: {note}")

    if problems:
        print(f"\n{len(problems)} problem(s):\n")
        for problem in problems:
            print(f"  {problem}")
        return 1

    if not args.quiet:
        print("\nall checks hold.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
