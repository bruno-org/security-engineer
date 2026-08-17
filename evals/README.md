# Evals

A written rule is not a check. This directory is where the rules get tested.

Two programs live here, and they answer two different questions.

| Program | Question it answers | Needs a model |
|---|---|---|
| `validate.py` | Is the package internally honest? | No |
| `run.py` | Does an agent carrying this skill actually catch the defect? | Yes |

---

## The pair rule

Every case is a pair: one file with a single planted defect, and the same file
with that defect repaired. The agent reviews both, and is never told which is
which.

| Variant | Required outcome | What it proves |
|---|---|---|
| `vulnerable/` | the defect is reported | the check catches what it exists to catch |
| `fixed/` | the defect is not reported | the check can also stay quiet |

**The second half is the point.** A check that fires on everything is not a
check, it is a stuck alarm, and it passes any suite that only ever feeds it
broken input. A case passes only when both halves do.

The same idea appears in the skill itself, as the negative control in
`references/verification.md`: an acceptance check that was never seen failing is
an assumption. Here the package applies it to its own material.

---

## Coverage

One case per layer. If a layer has no case, `validate.py` fails, for the same
reason the skill refuses a coverage matrix with a blank cell in it.

| Layer | Case | The planted defect |
|---|---|---|
| 1 Frontend | `01-frontend-client-side-gate` | Role read from the browser, profile text rendered as markup |
| 2 Backend and API | `02-backend-api-idor` | Record fetched by identifier with no ownership condition |
| 3 Data store | `03-data-store-rls-missing` | Table created with no row security and a table-wide grant |
| 4 Identity | `04-identity-jwt-unverified` | Token payload decoded, signature never verified |
| 5 Infrastructure | `05-infrastructure-container-root` | Container runs as root, credential baked into a layer |
| 6 Edge | `06-edge-plaintext-and-listing` | Plaintext transport, directory listing, version banner |
| 7 Observability | `07-observability-pii-in-logs` | Password and personal data logged and shipped to a vendor |
| 8 CI/CD | `08-cicd-untrusted-pr-build` | Fork code built with write permission and repository secrets |
| 9 Secrets | `09-secrets-in-client-bundle` | Privileged key exported into the browser bundle |
| 10 Dependencies | `10-dependencies-install-script` | Floating versions and an install script that fetches and runs code |
| 11 Public exposure | `11-public-exposure-source-served` | Project directory published, debug route dumping the environment |
| 12 Privacy | `12-privacy-collection-and-retention` | Data collected without a purpose, forwarded to analytics, never erased |
| 13 Payments | `13-payments-unverified-webhook` | Entitlement granted from an unsigned webhook, amount from the client |
| 14 AI surface | `14-ai-surface-agent-tool` | Untrusted page content reaching a database tool and an outbound channel |

---

## Running them

`validate.py` needs nothing but Python. Run it on every change to the package.

```
python evals/validate.py
```

It checks that the release stamp agrees in all four places, that the two READMEs
are still mirrors, that no document points at a path that does not exist, that
every layer playbook ends in an acceptance check, that every layer has a case,
and that no case has variants that are secretly identical.

`run.py` needs the `claude` command line tool, already authenticated. Nothing
else, no API key, no service.

```
python evals/run.py --self-test          # prove the scorer can fail, calls nothing
python evals/run.py --dry-run            # check the cases are well formed, calls nothing
python evals/run.py                      # the full suite
python evals/run.py --layer 3            # one layer
python evals/run.py --only 13 --only 02  # by id fragment
python evals/run.py --arm baseline       # the same review with the skill absent
python evals/run.py --json results.json
```

**Cost.** One model call per variant, so a full run is 28 calls. Start with
`--layer` or `--only` while you are iterating on a case, and keep the full run
for a release.

Exit code is 0 only when every vulnerable variant was caught and every fixed
variant was left alone.

### The three arms

| Arm | What it loads | Use it for |
|---|---|---|
| `skill` (default) | `SKILL.md` from this working copy | Scoring the file you are editing right now |
| `installed` | Nothing. Asks for the skill by name | Confirming the installed copy is found and loads |
| `baseline` | Nothing at all | Measuring what the skill adds over an ordinary review |

The baseline arm is the honest one to run before claiming the skill helps. If
the baseline catches everything, the skill is not what caught it.

---

## Adding a case

1. Create `cases/NN-slug/`, where `NN` is the layer number.
2. Write `vulnerable/<file>` with **one** planted defect. Keep it short and
   ordinary. A file that screams is not a test, it is a demonstration.
3. Write `fixed/<file>`: the same file, same shape, that one defect repaired.
   Everything else stays identical, so the pair isolates the variable.
4. Write `case.json`:

```json
{
  "id": "NN-slug",
  "title": "One line, what is wrong",
  "layer": 2,
  "layer_name": "Backend and API",
  "defaults": [3],
  "fixture": "handler.js",
  "signature": ["(?i)\\bIDOR\\b|ownership (check|condition)"],
  "why": "Why this defect matters, in one or two sentences."
}
```

5. `python evals/run.py --only NN --dry-run`, then run it for real.

**Writing the signature.** It is a list of regular expressions, and any one of
them matching the reported findings counts as a hit. Aim at the defect, not at
the vocabulary: match several ways a reviewer might name the same thing, and
never match a word that would also appear in a sensible finding about the fixed
file. If a case passes on the vulnerable half and fails on the fixed half, the
signature is usually too wide.

---

## What these do not prove

Stated plainly, because a harness that oversells itself is worse than none.

- **They are a regression harness, not a scoreboard.** Run the baseline arm and
  a capable model catches most of these on its own, which is the expected
  result: a planted defect in a thirty line file is the easy half of the job.
  What the skill adds is coverage, the walk that visits the layer nobody
  remembers, the live setting nobody read, and the ranking of what a control
  costs the humans using the product. None of that fits in one file. Use this
  suite to catch material that rots, not to claim a number.
- **They score one file at a time.** Most real defects are relationships between
  files, and no case here reproduces that.
- **The answer language is pinned to English**, so one scorer can read every run.
  A run therefore does not exercise the rule that the skill answers in the
  user's own language, which is a separate obligation with its own consequences
  when it fails.
- **They do not exercise the live surfaces.** Reading a real dashboard, checking
  which account is connected, confirming a setting is actually on: none of that
  is testable offline, and it is a large part of what the skill does.
- **They measure the report, not the repair.** A pass means the defect was named,
  not that the suggested fix was correct.
- **Model output varies between runs.** A single miss is a reason to look, not a
  verdict. Re-run before concluding anything, and prefer a case that fails
  consistently over one that failed once.
- **Passing is not a security guarantee for anyone's system.** These are fourteen
  known defects on fourteen small files. Real systems have the other kind.
