# Verification

A control that cannot be proven is a wish. Every MUST in the plan carries an acceptance check, and the check is written at the same moment as the control, not later.

Three rules govern this file:

1. **The load-bearing control gets the test.** Whatever single mechanism carries the most weight, usually the data access rules, is the one most likely to ship untested. Invert that.
2. **Verify from the attacker's position, not the operator's.** An administrator console shows what the operator is allowed to see. It does not show what an anonymous caller can reach. The two views disagree more often than teams expect.
3. **A check nobody has watched fail is an assumption.** See the negative control below. It is one extra minute per check and it is the difference between a test suite and a decoration.

---

## The negative control

Before a check counts as passing, make it fail on purpose once.

Break the thing it is supposed to be watching, in a scratch branch or a local
copy, run the check, and confirm it goes red. Then put it back and confirm it
goes green. Both directions, in that order.

| The check | How to break it on purpose | What a broken check looks like |
|---|---|---|
| Cross-tenant denial test | Disable the policy on the table, or run the query as the privileged role | Still green, because it was asserting against a mocked layer or an empty result set |
| Unauthenticated access sweep | Remove the guard from one route | Still green, because the route table it enumerates is stale or hand-maintained |
| Secret scanning in the pipeline | Commit a fake credential shaped like a real one, on a branch | Still green, because it scans the current state rather than the history, or the job continues on error |
| Live probe for exposed paths | Point it at a path you know is published | Still green, because a single-page fallback answered and the size was never compared |
| Rate limit | Call the endpoint past the limit from one address | Still green, because the limiter is keyed on something the caller controls |
| Webhook signature check | Send an unsigned payload | Still green, because the framework parsed the body before the signature was computed over the raw bytes |

This is where checks are actually found to be broken. The usual cause is not a
wrong assertion, it is a check pointed at the wrong thing: a mock instead of the
real policy, the working tree instead of the history, a route list that stopped
being updated. All of them pass forever and prove nothing, and none of them look
wrong when you read them.

**Write the negative result down.** One line next to the acceptance check saying
what was broken and that the check caught it. It is the only evidence that the
green result means anything, and it is what a customer questionnaire is actually
asking for when it asks how you know.

**The same rule applies to this package.** Its own material is exercised against
paired fixtures, one with a planted defect and one with the defect repaired, and
a check that fires on both is treated as broken. See `evals/README.md`.

---

## The verification pyramid

| Level | What it proves | When it runs |
|---|---|---|
| Design review | The decision is right | Before code |
| Automated test | The rule holds for this case | Every commit |
| Scanner | No known-bad patterns or dependencies | Every commit and on a schedule |
| Live probe | The deployed system behaves as designed | Before launch, after infrastructure change |

All four. Each catches what the others cannot.

---

## Automated tests that earn their keep

Write these as ordinary tests in the project's existing framework. No new tooling.

**1. Cross-tenant denial.** The single most valuable security test in a multi-user product.

```
setup (shared by both tests):
  a = createUser(); b = createUser()

test('user A cannot read user B records'):
  recordB = createRecord(as: b)
  result = readRecord(recordB.id, as: a)
  expect(result.rowCount).toBe(0)

test('user A cannot write into user B tenant'):
  result = createRecord({ tenantId: b.tenantId }, as: a)
  expect(result).toRaiseError()
```

The two assertions differ because row level security treats the two operations differently: a policy filters a read, so a cross-tenant select returns zero rows and no error, and it rejects a write, which raises one. A read test that asserts a denial fails against a correct system, and the usual repair is to loosen the assertion until nothing can fail it.

Run it against the real data rules, using a real client credential, not a mocked layer. Mocking the thing under test proves nothing.

**2. Privilege escalation attempt.**

```
test('normal user cannot set privileged fields'):
  for field in ['role', 'plan', 'isAdmin', 'credits', 'verified', 'subscriptionStatus']:
    result = updateOwnProfile({ [field]: elevatedValue }, as: normalUser)
    expect(readProfile(normalUser)[field]).toBeUnchanged()
```

**3. Unauthenticated access sweep.** Enumerate the route table and call each protected route with no session. Any status other than a rejection is a finding. This catches the route someone added last week without a guard.

**4. Ownership on every object type.** For each resource: read, update, and delete another owner's object by identifier, and assert an identical response to the not-found case.

**5. Input rejection.** Oversized payloads, wrong types, and a scripted string through every user-content path, asserting it comes back as text.

**6. Upload rejection.** A file whose extension lies about its contents, an oversized file, and a markup file renamed to an image extension.

**7. Webhook forgery.** Post an unsigned and a wrongly signed payload to every webhook endpoint. Both rejected. Then post the same valid event twice and assert the effect happened once.

---

## Scanners

Complements to reading the code, never a replacement. Reading finds the logic flaws, which is most of what matters. Scanners find the volume.

| Kind | Purpose | Notes |
|---|---|---|
| Static analysis | Dangerous patterns, injection, hardcoded credentials | Multi-language rule engines are customizable, for example Semgrep or OpenGrep. Language-specific analyzers are stronger for their language, for example Bandit for Python (shell execution, deserialization, weak cryptography), gosec for Go, Brakeman for Ruby on Rails, and the eslint security plugins for JavaScript |
| Dependency scanning | Known vulnerabilities in what you depend on | The ecosystem native auditors, for example `npm audit` and `pip-audit`, plus `osv-scanner` across ecosystems, plus Dependabot or Renovate for automated updates. Run in the pipeline and on a schedule, since new advisories land for code you did not touch |
| Secret scanning | Credentials in the working tree and in history | Run gitleaks or trufflehog over the entire history, not just the current state. Enable the repository host's push protection so the block happens before the leak |
| Container and image scanning | Vulnerable packages in base images | Only for container profiles, for example Trivy or Grype |
| Dynamic scanning | The running application from outside | Useful for headers, transport, and injection surface, for example OWASP ZAP. Active scanning is intrusive: run against a staging environment, or with explicit authorization and a maintenance window |
| Infrastructure scanning | Misconfiguration in infrastructure definitions | For teams with infrastructure as code, for example Checkov or tfsec |

**On dynamic scanning:** it tests what is deployed rather than what was designed, which is exactly why it finds things reviews miss. It also generates traffic that looks like an attack, so coordinate before pointing it at anything shared.

---

## Live probes before launch

Run from outside, unauthenticated, from a network that is not the developer's.

```
# Transport and headers on the canonical host and the bare domain
curl -sI https://CANONICAL/
curl -sI https://BARE-DOMAIN/

# Confirm the platform preview hostname is not an open door
curl -sI https://PROJECT.PREVIEW-HOST/

# Confirm the published artifact contains only intended files
for p in .env .env.local .git/HEAD .git/config package.json composer.json \
         backup.zip dump.sql config.yml docker-compose.yml .DS_Store; do
  printf '%s -> ' "$p"
  curl -s -o /dev/null -w '%{http_code} %{size_download}\n' "https://CANONICAL/$p"
done
```

`assets/probe.sh` runs these against a host you name, including the path sweep, the baseline comparison below, and the cache arithmetic that follows it. The commands above are what it does, written out.

Interpretation matters: single-page applications answer every path with the same fallback page, so a success status alone means nothing. Compare the response size against a path that certainly does not exist. Equal size means fallback, which is fine. A different size means a real file is being served, which is a finding.

Where an edge cache sits in front, check the same path twice, once plain and once with a unique query string that forces a fresh fetch. A difference between the two means the cache is serving content the origin no longer has, which is a leak that no origin fix will clear.

Quantify it from the response headers. The `Age` header gives the seconds the object has already been served from cache, and the `s-maxage` directive in `Cache-Control` gives the ceiling, so `s-maxage` minus `Age` is the remaining exposure window in seconds. That number decides the response: purging the cache is enough when the leak came from a one-off publish, and the publishing pipeline itself has to change when it will republish the same file, since purging does not fix a pipeline that puts the file back.

**Data platform probes, using only the public client credential:**

```
# Read a table that should be closed
# Write to a table that should be closed
# Read a record belonging to another tenant
# List storage buckets and attempt to read an object
# Check whether public registration is enabled on the identity module
# Decode the client token and confirm its lifetime is intentional
```

Every one must be denied, except where openness is a documented product decision.

**Restraint:** probe enough to prove the control, never enough to degrade the service. A handful of requests per endpoint proves a rate limiter engages. Hundreds is an attack on your own product.

**Cleanup:** if a probe creates anything, a test account, a record, a file, list it and remove it. Never leave test artifacts in a production system.

---

## Verifying your own output

The most common source of a hole is the design that was just produced, including by this skill. Before delivering any schema, endpoint, or configuration you generated, re-read it against the Five Defaults, and specifically check:

- Every foreign key that crosses a tenant boundary. A correctly scoped parent row can reference a child belonging to someone else, and the parent check passes while the child leaks. Enforce the relationship in the schema so the database refuses it.
- Every field a client can send, compared against the fields the server actually intends to accept. Anything else is ignored explicitly, not accepted implicitly.
- Every error path, checking that internal details do not travel to the client.
- Every new table, bucket, or collection introduced, confirming rules were enabled at creation.
- Every privileged operation added, confirming it is authorized server-side and logged, including its denials.

State plainly what you did not cover. An honest gap that the team knows about is manageable. A silent one is not.

---

## Cadence after launch

| Trigger | What to re-run |
|---|---|
| Every commit | Automated tests, static analysis, secret and dependency scanning |
| Every new table, bucket, or endpoint | Cross-tenant and ownership tests for it, plus the rules check |
| Every infrastructure change | Live probes and origin reachability |
| Monthly | Dependency advisories, platform module defaults, access review |
| Quarterly | Full external review, credential rotation check, restore test from backup |
| After any incident | Everything, plus rotation of anything the incident could have exposed |

A restore that has never been tested is not a backup. Test it on the calendar, not on the worst day.

---

## OWASP mapping

Two published lists are used, and both are fetched rather than recalled:

- **OWASP Top 10.** Common web risk categories.
- **OWASP API Security Top 10.** API specific risks, where broken object level authorization is ranked first.

**Fetch them, then map onto what you fetched.** When the user asks for standards traceability, and whenever the engagement produces a plan or a review, retrieve the current revision of both lists before writing the mapping. They are short, public, and revised every few years, so a list recalled from memory will name categories that have since been renumbered, merged, or dropped, and the mapping will file real findings under identifiers that no longer mean what they meant. Map the findings and the layer decisions onto the category identifiers of the revision just fetched, and name that revision and its year in the output, so the reader knows which one was used. With no network access, state which revision is being used from memory and flag it as not verified against the published list.

**That mapping is the entire standards scope of this package.** It performs no conformance assessment against any framework and produces no certification of any kind.

**When a customer questionnaire or a procurement process arrives,** the output is the coverage matrix plus the acceptance-check evidence, described in the vocabulary the questionnaire uses. Never answer with a claim of certification.
