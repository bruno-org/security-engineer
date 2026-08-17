#!/usr/bin/env python3
"""Behavioural harness for the Security Engineer skill.

Every case in cases/ is a pair: a file with one planted defect, and the same
file with that defect repaired. The agent reviews both without being told
which is which.

    vulnerable  ->  the finding MUST appear      (the check catches it)
    fixed       ->  the finding MUST NOT appear  (the check can also stay quiet)

The second half is the point. A check that fires on everything is not a check,
it is a stuck alarm, and it passes any suite that only ever feeds it broken
input. A case passes only when both halves do.

Requires the `claude` command line tool, already authenticated. Nothing else.

    python evals/run.py                      # every case, both variants
    python evals/run.py --only 03 --only 13  # by id fragment
    python evals/run.py --layer 3            # by layer number
    python evals/run.py --arm baseline       # same cases, skill not loaded
    python evals/run.py --dry-run            # validate the cases, call nothing
    python evals/run.py --json results.json  # machine readable output

Cost: one model call per variant, so 28 calls for a full two-variant run.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
CASES_DIR = ROOT / "cases"

TASK = """Review the file below and report only security defects that are actually present in it.

Rules for your answer:
- Report a defect only if it is really there. Do not report style, structure, missing features, or hardening this file does not need.
- If the file has no security defect, return an empty list. An empty list is a valid and expected answer.
- Answer with JSON and nothing else. No prose before or after, no code fence.

Shape:
{"findings": [{"severity": "critical|high|medium|low", "summary": "one sentence naming the defect", "evidence": "the line or construct that causes it"}]}

FILE: %(name)s
%(fence)s
%(content)s
%(fence)s
"""

INSTALLED_PREFIX = "Use the security-engineer skill for this review.\n\n"

VARIANTS = ("vulnerable", "fixed")

# skill      the instructions in SKILL.md are loaded for the review
# installed  the skill is expected to already be installed in the agent, and is
#            asked for by name, which also exercises whether it loads at all
# baseline   the same review with nothing loaded, to measure what the skill adds
ARMS = ("skill", "installed", "baseline")


def load_cases(filters: list[str], layers: list[int]) -> list[dict]:
    cases = []
    for case_file in sorted(CASES_DIR.glob("*/case.json")):
        meta = json.loads(case_file.read_text(encoding="utf-8"))
        meta["dir"] = case_file.parent
        if filters and not any(f in meta["id"] for f in filters):
            continue
        if layers and meta["layer"] not in layers:
            continue
        cases.append(meta)
    return cases


def check_case(meta: dict) -> list[str]:
    """Structural problems with the case itself. Empty list means well formed."""
    problems = []
    for key in ("id", "title", "layer", "layer_name", "fixture", "signature", "why"):
        if key not in meta:
            problems.append(f"missing key '{key}'")
    for variant in VARIANTS:
        path = meta["dir"] / variant / meta.get("fixture", "")
        if not path.is_file():
            problems.append(f"missing fixture {variant}/{meta.get('fixture')}")
    for pattern in meta.get("signature", []):
        try:
            re.compile(pattern)
        except re.error as exc:
            problems.append(f"bad signature regex {pattern!r}: {exc}")
    if not meta.get("signature"):
        problems.append("no signature patterns, so nothing can be scored")
    # The two variants must actually differ, otherwise the pair proves nothing.
    a = meta["dir"] / "vulnerable" / meta.get("fixture", "")
    b = meta["dir"] / "fixed" / meta.get("fixture", "")
    if a.is_file() and b.is_file() and a.read_bytes() == b.read_bytes():
        problems.append("vulnerable and fixed are identical")
    return problems


def run_agent(prompt: str, arm: str, model: str | None, timeout: int) -> tuple[str, str | None]:
    """Return (text, error). Text is the agent's raw answer."""
    binary = shutil.which("claude")
    if not binary:
        return "", "the 'claude' command was not found on PATH"

    cmd = [binary, "-p", "--output-format", "json"]
    if arm == "skill":
        # Loaded directly from this working copy, so the run scores the file in
        # front of you rather than whatever version happens to be installed.
        cmd += ["--append-system-prompt", (ROOT.parent / "SKILL.md").read_text(encoding="utf-8")]
    if model:
        cmd += ["--model", model]

    try:
        proc = subprocess.run(
            cmd,
            input=prompt,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return "", f"timed out after {timeout}s"

    if proc.returncode != 0:
        return "", f"exit {proc.returncode}: {(proc.stderr or '').strip()[:300]}"

    try:
        envelope = json.loads(proc.stdout)
        return str(envelope.get("result", "")), None
    except json.JSONDecodeError:
        return proc.stdout, None


def parse_findings(text: str) -> tuple[list[dict], str | None]:
    """Pull the findings array out of whatever the agent answered."""
    candidate = text.strip()
    fenced = re.search(r"```(?:json)?\s*(.+?)```", candidate, re.S)
    if fenced:
        candidate = fenced.group(1).strip()
    start, end = candidate.find("{"), candidate.rfind("}")
    if start == -1 or end == -1:
        return [], "no JSON object in the answer"
    try:
        payload = json.loads(candidate[start : end + 1])
    except json.JSONDecodeError as exc:
        return [], f"unparseable JSON: {exc}"
    findings = payload.get("findings", [])
    if not isinstance(findings, list):
        return [], "'findings' is not a list"
    return [f for f in findings if isinstance(f, dict)], None


def signature_hit(findings: list[dict], signature: list[str]) -> str | None:
    """Return the pattern that matched the findings text, or None."""
    blob = "\n".join(
        f"{f.get('summary', '')} {f.get('evidence', '')} {f.get('title', '')}"
        for f in findings
    )
    for pattern in signature:
        if re.search(pattern, blob):
            return pattern
    return None


def run_one(meta: dict, variant: str, arm: str, model: str | None, timeout: int) -> dict:
    fixture = meta["dir"] / variant / meta["fixture"]
    prompt = TASK % {
        "name": meta["fixture"],
        "content": fixture.read_text(encoding="utf-8"),
        "fence": "```",
    }
    if arm == "installed":
        prompt = INSTALLED_PREFIX + prompt

    text, error = run_agent(prompt, arm, model, timeout)
    result = {
        "case": meta["id"],
        "layer": meta["layer"],
        "variant": variant,
        "arm": arm,
        "error": error,
    }
    if error:
        result["verdict"] = "ERROR"
        return result

    findings, parse_error = parse_findings(text)
    if parse_error:
        result["verdict"] = "ERROR"
        result["error"] = parse_error
        result["raw"] = text[:400]
        return result

    matched = signature_hit(findings, meta["signature"])
    result["findings"] = len(findings)
    result["matched"] = matched
    if variant == "vulnerable":
        result["verdict"] = "CAUGHT" if matched else "MISSED"
    else:
        result["verdict"] = "QUIET" if not matched else "FALSE ALARM"
    if result["verdict"] in ("MISSED", "FALSE ALARM"):
        result["reported"] = [f.get("summary", "") for f in findings][:5]
    return result


def self_test() -> int:
    """Prove the scorer can fail. It calls nothing and needs no network.

    A harness that only ever sees passing runs is worth as much as an acceptance
    check nobody tried to break, so the four verdicts are exercised against
    fixed answers with a known right result.
    """
    signature = ["(?i)\\bIDOR\\b|ownership (check|condition)"]
    caught = '{"findings": [{"severity": "high", "summary": "IDOR on the invoice route", "evidence": "where id = $1"}]}'
    silent = '{"findings": []}'
    unrelated = '{"findings": [{"severity": "low", "summary": "no request timeout is configured", "evidence": "db.query"}]}'
    fenced = "Here you go:\n```json\n" + caught + "\n```"

    cases = [
        ("a real hit is scored as a hit", caught, True),
        ("an empty answer is scored as a miss", silent, False),
        ("an unrelated finding does not count as a hit", unrelated, False),
        ("a fenced answer is still parsed", fenced, True),
    ]

    failures = 0
    for label, answer, expected in cases:
        findings, error = parse_findings(answer)
        got = bool(signature_hit(findings, signature)) if not error else False
        ok = got == expected
        failures += 0 if ok else 1
        print(f"  [{'ok' if ok else 'FAIL':>4}] {label}")

    broken, error = parse_findings("I could not review this file.")
    ok = error is not None
    failures += 0 if ok else 1
    print(f"  [{'ok' if ok else 'FAIL':>4}] a non-answer is reported as an error, not as a pass")

    print("\nthe scorer can distinguish a hit from a miss." if not failures
          else f"\n{failures} scorer check(s) failed.")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", action="append", default=[], metavar="FRAGMENT", help="run cases whose id contains this")
    parser.add_argument("--layer", action="append", type=int, default=[], help="run cases for this layer number")
    parser.add_argument("--variant", choices=VARIANTS, help="run only one half of each pair")
    parser.add_argument("--arm", choices=ARMS, default="skill", help="skill loaded from this copy, asked for by name, or not loaded at all")
    parser.add_argument("--model", help="passed through to the agent")
    parser.add_argument("--timeout", type=int, default=240, help="seconds per call")
    parser.add_argument("--jobs", type=int, default=3, help="calls in flight at once")
    parser.add_argument("--dry-run", action="store_true", help="validate the cases and print the plan, call nothing")
    parser.add_argument("--self-test", action="store_true", help="prove the scorer can fail, call nothing")
    parser.add_argument("--json", metavar="PATH", help="write the full result set here")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    cases = load_cases(args.only, args.layer)
    if not cases:
        print("no cases matched", file=sys.stderr)
        return 2

    malformed = False
    for meta in cases:
        for problem in check_case(meta):
            print(f"case {meta['id']}: {problem}", file=sys.stderr)
            malformed = True
    if malformed:
        return 2

    variants = [args.variant] if args.variant else list(VARIANTS)
    jobs = [(meta, variant) for meta in cases for variant in variants]

    print(f"{len(cases)} case(s), {len(jobs)} call(s), arm={args.arm}\n")
    if args.dry_run:
        for meta in cases:
            print(f"  layer {meta['layer']:>2}  {meta['id']}  {meta['title']}")
        print("\ncases are well formed. Nothing was called.")
        return 0

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futures = {
            pool.submit(run_one, meta, variant, args.arm, args.model, args.timeout): (meta, variant)
            for meta, variant in jobs
        }
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"  {result['verdict']:<12} {result['case']} [{result['variant']}]"
                  + (f"  {result['error']}" if result.get("error") else ""))

    order = {c["id"]: i for i, c in enumerate(cases)}
    results.sort(key=lambda r: (order[r["case"]], r["variant"]))

    caught = sum(1 for r in results if r["verdict"] == "CAUGHT")
    missed = sum(1 for r in results if r["verdict"] == "MISSED")
    quiet = sum(1 for r in results if r["verdict"] == "QUIET")
    alarms = sum(1 for r in results if r["verdict"] == "FALSE ALARM")
    errors = sum(1 for r in results if r["verdict"] == "ERROR")

    print("\n" + "-" * 72)
    print(f"  vulnerable   caught {caught}, missed {missed}")
    print(f"  fixed        quiet  {quiet}, false alarm {alarms}")
    if errors:
        print(f"  errors       {errors}")
    print("-" * 72)

    for result in results:
        if result["verdict"] in ("MISSED", "FALSE ALARM"):
            print(f"\n{result['verdict']}: {result['case']} [{result['variant']}]")
            for summary in result.get("reported", []) or ["(nothing reported)"]:
                print(f"    reported: {summary}")

    if args.json:
        pathlib.Path(args.json).write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(f"\nwrote {args.json}")

    return 1 if (missed or alarms or errors) else 0


if __name__ == "__main__":
    sys.exit(main())
