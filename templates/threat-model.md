# Threat Model: {SYSTEM NAME}

One page. A threat model nobody reads protects nothing.

---

## What we are protecting

| Asset | Why it matters | What it costs if lost |
|---|---|---|
| {customer records} | {trust, contractual duty, regulatory exposure} | {concrete consequence} |
| {credentials and tokens} | | |
| {money movement} | | |
| {availability} | | |
| {reputation and sender domain} | | |

---

## Trust boundaries

Every arrow crossing a boundary is a place where input is validated and identity is verified.

```
[ browser or app ]  --(1)-->  [ our server ]  --(2)-->  [ data store ]
        |                          |
        (3)                        (4)
        v                          v
  [ data platform direct ]    [ third parties: payments, mail, analytics ]
```

| # | Boundary | What crosses it | Verified how |
|---|---|---|---|
| 1 | Client to server | {requests, uploads} | {session verification, schema validation} |
| 2 | Server to data | {queries, writes} | {parameterized, owner-scoped} |
| 3 | Client direct to platform | {queries with public key} | {platform access rules, the only control here} |
| 4 | Server to third parties | {payloads, webhooks inbound} | {signature verification, allowlists} |
| 5 | Model context (conditional) | {prompts, retrieved documents, tool calls and their results} | {authorization in the calling code, retrieval filtered per user, output encoded at the sink} |

Boundary 5 applies when the system sends a prompt to a model at runtime, retrieves documents for one, or exposes a tool to one. When it does not, write Not applicable with that reason in the row rather than deleting it.

---

## Tier 0: the automated opportunist

Always modeled. Arrives within minutes of going live, does not choose us.

| What it tries | Reaches us? | Structural defense |
|---|---|---|
| Version and vulnerability scanning | | |
| Common path probing (environment files, version control, admin panels, backups) | | |
| Identifier walking on API resources | | |
| Credential stuffing and brute force | | |
| Public repository and bundle secret harvesting | | |
| Volumetric flood | | |
| Open registration and mail relay abuse | | |
| Default credentials | | |

Structural means it holds without anyone remembering to do anything.

---

## Tier 1: the motivated adversary

| Question | Answer |
|---|---|
| Who would target this specifically | |
| Motive | {money, competition, grievance, ideology, data resale} |
| Capability assumed | {tooling, purchased breach data, time, budget} |
| Entry points they would study | |
| What they gain on success | |

### Chained scenarios

Written as sentences about this system, not as categories. At least three.

1. **{Name}:** {step} which yields {step} which yields {impact}.
   - Weakest link in the chain: {where we break it}
2. **{Name}:** {...}
3. **{Name}:** {...}

---

## Denial of service, three flavors

| Flavor | Applies here? | Defense |
|---|---|---|
| Volumetric flood | | {edge absorption, origin not directly reachable} |
| Application exhaustion (expensive endpoint, pathological input) | | {limits, timeouts, input bounds} |
| Cost exhaustion (metered service, paid quota) | | {rate limits, quotas, spend caps, alerts} |

---

## What we accept

| Risk | Why accepted | Owner | Revisit when |
|---|---|---|---|
| | | | |

---

## Detection and recovery

| Question | Answer |
|---|---|
| How would we notice a breach | |
| How fast | |
| Can we revoke every credential quickly | |
| Can we restore from backup, and when was it last tested | |
| Who is contacted, in what order | |
| Notification duty and its clock | |

---

> Review this document when the stack changes, when the data class rises, when a new integration is added, and at least quarterly.
