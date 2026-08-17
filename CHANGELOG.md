# Changelog

All notable changes to this package are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the package follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Check the date before you rely on a copy.** Security guidance ages. Algorithms get deprecated,
provider defaults change, a header value that was correct becomes obsolete, and a recommended tool
picks up a CVE. Compare the date on the release you are running against the latest entry below.

Version numbers mean this: **MAJOR** when a decision changes in a way that invalidates a plan already
written with an earlier release, **MINOR** when a layer, a control, or an acceptance check is added,
**PATCH** for wording and formatting that leaves every decision as it was.

**Releasing:** every release bumps four places that must agree, or the freshness signal becomes a
lie: the `version` field in `SKILL.md`, the entry below, and the version and date shown at the top of
`README.md` and `README.pt-BR.md`.

---

## [Unreleased]

### Added

- `evals/`, the harness this package is tested with. Fourteen cases, one per layer, each a pair: a
  file carrying a single planted defect and the same file with that defect repaired. A case passes
  only when the defect is reported on the first and left alone on the second, so a check that fires
  on everything fails the suite instead of passing it.
- `evals/run.py`, which scores those pairs through the `claude` command line tool, with three arms:
  the skill loaded from the working copy, the skill asked for by name to confirm an installed copy
  loads, and no skill at all to measure what it adds. Also `--self-test`, which proves the scorer
  itself can fail without calling a model, and `--dry-run`, which checks the cases are well formed.
- `evals/validate.py`, integrity checks that need no model and no network: the release stamp agrees
  in all four places, the two READMEs stay mirrors, no document points at a path that does not
  exist, every layer playbook ends in an acceptance check, every layer has a case, and no case has
  variants that are secretly identical.
- The negative control in `references/verification.md`: an acceptance check counts as passing only
  after the control it watches has been broken on purpose once and the check was seen going red.
  Includes the six checks that most often pass while pointed at the wrong thing, and how to break
  each one. Rule 5 in `SKILL.md` now carries the same obligation.
- `references/change-review.md`, Mode C on a diff: what a diff hides, which layers each class of
  change actually reaches, the five questions a finding clears before it is written down, the
  categories that are never reported, and the merge gate the review produces instead of a list.
- Dependency triage in layer 10, so a scanner queue becomes an ordered plan: confirmed exploitation
  in the wild first, then reachability in production, then likelihood of the attempt, then whether a
  fix can actually be taken. Suppressions now expire.

### Changed

- The acceptance check for layer 10 asks for the triaged queue rather than a severity count.
- Step 5 of the workflow now states the precision bar for reported findings.

---

## [1.0.0] - 2026-08-17

Initial release. The package is the skill file, eight reference documents, and three templates read
by a coding agent, plus an `assets/` directory of reference artifacts meant to be copied into a
project: a probe script, a SQL policy file, a CI workflow, a header configuration reference, and a
cross-tenant test file. The instructions run nothing on their own; the artifacts are code and are
read before use.

Scope is design-time and build-time security engineering, for the moment when a control is still a
configuration change. It performs no conformance assessment and produces no certification.

### Added

- `SKILL.md`, the operating instructions: the thirteen core layers that each require a written
  decision plus a conditional fourteenth for model and agent features, the five application defaults
  checked on every feature, the four-rank friction scale that picks the cheapest control that closes
  the risk, the discovery pass that reads the project before advising, the three entry modes (new
  project, project underway, single feature or pull request), the consolidated access request for
  administrative surfaces the session cannot reach, and the blocking pre-launch gate.
- `references/threat-model.md`: the automated opportunist and the motivated adversary, and what each
  one implies at design time.
- `references/layer-playbooks.md`: decisions, controls, acceptance checks, and friction rank for all
  thirteen core layers (frontend, backend, data, identity, infrastructure, edge, observability,
  pipeline, secrets, dependencies, public exposure, privacy, payments).
- `references/ai-surface.md`: the conditional layer for systems that ship a model or agent feature,
  covering prompt injection, tool authorization, retrieval isolation, and cost limits.
- `references/app-defaults.md`: the five defaults, each with its secure pattern and the insecure twin
  it is usually confused with, plus the quota question that turns a denial of service into an invoice.
- `references/stack-profiles.md`: what changes across serverless, self-hosted, and local-only
  deployments.
- `references/verification.md`: how to prove a control holds, and the scanner toolkit.
- `references/live-surfaces.md`: how to verify and change the real configuration of the providers a
  system runs on, with the tool preference order (connected MCP server, provider CLI, authenticated
  browser, ask the user), the rule that the account, organization and project are confirmed before
  the first call, and the per-surface checks for source control, managed database and backend
  platforms, hosting and edge, identity providers, observability, payments, registrar and DNS, cloud
  accounts, and self-hosted servers.
- `references/operating-discipline.md`: language, consent before changes, disclosure limits, and what
  stays private to the team.
- `templates/security-plan.md`: the deliverable, with a slot for every layer decision.
- `templates/pre-launch-checklist.md`: the blocking gate covering what an automated attacker tries
  first.
- `templates/threat-model.md`: a one-page model.
- `assets/`, copyable artifacts with a `README.md` that lists the placeholders each one needs:
  `rls-multitenant.sql` (PostgreSQL tenant isolation, row level security enabled and forced, one
  policy per command, composite foreign keys), `security-headers.md` (header values, nginx and Node
  configuration, the report-only rollout path for `Content-Security-Policy`), `ci-security.yml` (a
  GitHub Actions workflow with secret scanning, dependency audit, static analysis, and actions
  pinned by commit SHA), `probe.sh` (an external pre-launch probe against a host you name), and
  `tenancy.test.example.ts` (the cross-tenant denial suite run as an unprivileged client).
- `README.md` and `README.pt-BR.md`, the same overview in English and in Brazilian Portuguese, with
  `docs/img/cover.png`, the cover image both of them display.
- `SECURITY.md` (what is in scope and how to report it), `.gitignore`, and `LICENSE` (MIT).
- Mapping onto the OWASP Top 10 and the OWASP API Security Top 10, fetched at run time so the
  category identifiers match the current revision, with the revision and year named in the output.
