# Security Plan: {SYSTEM NAME}

> Written in the user's language. Headings translated, control identifiers kept in English.
> Date: {DATE} | Author: {WHO} | Stage: {idea | design | building | pre-launch | live}

---

## 1. In plain language

{Four to eight sentences a non-technical founder reads in two minutes. What this system holds, who would want it, what we are protecting against, and what the plan does about it. No jargon. No acronyms.}

**The short version:** {N} things must be true before this goes live. {M} more are strongly recommended. Everything else is written down as a conscious decision to do later.

Fit the length to the reader: lead with this summary and the ordered blocking list in section 5, and compress every other section when the audience is one non-technical person.

---

## 2. What this system is

| Question | Answer |
|---|---|
| Profile | {managed and serverless / self-hosted / client-direct database / mobile or desktop / local-only / internal tool / blend} |
| Data held | {anonymous, personal, financial, health, credentials, regulated} |
| Highest sensitivity class | {sets the bar for everything below} |
| Exposure | {public internet / authenticated only / internal / offline} |
| Who operates it | {solo, small team, org} |
| Blast radius if fully compromised | {what the attacker gains, what it costs the owner, in concrete terms} |
| Regulatory regime | {none / GDPR / LGPD / HIPAA / PCI / other} |

### What could be verified, and how

One row per administrative surface in the stack. This is what justifies each layer marked as verified live, and what a Pending manual verification status points back to.

| Surface | How it was verified |
|---|---|
| {hosting and edge account} | {connected tool / CLI / browser session / user-reported / not reachable} |
| {database or backend platform} | |
| {source control organization} | |

---

## 3. Threat model

### Tier 0, the automated opportunist (always modeled)

{Two or three sentences about what a scanner reaching this specific system would try first, and what it would find today.}

Structural defenses that make Tier 0 fail without anyone remembering anything:
- {defense}
- {defense}

### Tier 1, the motivated adversary

{Who would target this specifically, and why. Financial, competitive, personal, or reputational motive.}

Chained scenarios, written as sentences about this system:
1. {Attacker does X, which gives Y, which reaches Z.}
2. {...}
3. {...}

---

## 4. Layer decisions (the coverage matrix)

Status is one of: **Decided** (control chosen and specified), **Deferred** (with reason and owner), **Pending manual verification** (with the surface name, the reason access was missing, and an owner), **Not applicable** (with reason). No blank cells.

Pending manual verification means the control could not be verified because the surface was not reachable in this session. It is not a pass and it is not a deferral: it means unknown. Anything still Pending when the pre-launch gate runs gets raised again rather than passed silently.

When the check runs is one of: **at build time** (runs today, on the code as it stands), **before first deploy** (needs a running environment, a domain, or a real credential), **on every commit thereafter** (wired into CI and repeated). On a greenfield system most checks cannot run yet, so record the moment each one becomes runnable.

Layers 1 to 13 are the core set and always get a row. Layer 14 is conditional: it applies when the system sends a prompt to a model at runtime, retrieves documents for one, or exposes a tool to one, and it is recorded as Not applicable with that reason when it does not. The row stays either way.

| # | Layer | Decision | Level | Status | Acceptance check | When the check runs |
|---|---|---|---|---|---|---|
| 1 | Frontend | | MUST/SHOULD/MAY | | | {at build time / before first deploy / on every commit thereafter} |
| 2 | Backend and API | | | | | |
| 3 | Data store | | | | | |
| 4 | Identity and authorization | | | | | |
| 5 | Infrastructure and network | | | | | |
| 6 | Edge: CDN, TLS, DNS, email | | | | | |
| 7 | Observability | | | | | |
| 8 | CI/CD and pipeline | | | | | |
| 9 | Secrets | | | | | |
| 10 | Dependencies and supply chain | | | | | |
| 11 | Public exposure | | | | | |
| 12 | Privacy and compliance | | | | | |
| 13 | Payments and integrations | | | | | |
| 14 | AI surface: model and agent features (conditional) | | | | | |

---

## 5. MUST: blocking before launch

Ordered by what an automated attacker reaches first.

### M1. {Title in human words}

- **Plain language:** {what it is, why it matters, what could happen, what to do}
- **Layer:** {layer}
- **Change to make:** {exact configuration, code, or command}
- **Acceptance check:** {the command or test that proves it}
- **When the check runs:** {at build time / before first deploy / on every commit thereafter}
- **Effort:** {minutes or hours}
- **Friction rank:** {1 to 4, and who feels it}

### M2. {...}

---

## 6. SHOULD: expected for this profile

| # | Control | Layer | Why it matters here | Acceptance check | Effort | Friction |
|---|---|---|---|---|---|---|
| S1 | | | | {only when the check is not obvious} | | |

---

## 7. MAY: revisit when the system grows

| # | Control | Trigger that makes it worth doing |
|---|---|---|
| A1 | | {first paying customer, first employee, data class rises, volume threshold} |

---

## 8. Accepted risks

Decisions made knowingly. Each one has an owner and a revisit trigger.

| Risk | Why accepted | Owner | Revisit when |
|---|---|---|---|
| | | | |

---

## 9. Friction notes

Where a control touches the experience, and what was considered instead.

| Control | Who feels it | Rank | Cheaper alternative considered | Why the chosen one won |
|---|---|---|---|---|
| | | | | |

---

## 10. The Five Defaults plus the sixth question, per feature

Reusable check for every feature that touches data, identity, money, files, or the network.

- [ ] Data rules deny by default, scoped per owner, enabled at creation
- [ ] Authorization decided on the server, never read from the client
- [ ] Ownership verified per object, including cross-tenant foreign keys
- [ ] Secrets server-side only, absent from the bundle and from history
- [ ] All input validated server-side, uploads validated by real content
- [ ] Sixth question: what stops this from being called a million times

---

## 11. What was not covered

{Honest list: no access, out of scope, deferred, unknown. Anything left blank here becomes a surprise later.}

---

## 12. OWASP mapping

Produced whenever the engagement produces a plan or a review, and whenever the user asks for traceability. Fetch both lists before writing this section, per references/verification.md.

**Revision used:** {OWASP Top 10 {YEAR} and OWASP API Security Top 10 {YEAR}, fetched on {DATE}} | {recalled from memory and not verified against the published list}

| Finding or layer decision | OWASP category identifier | List and revision used |
|---|---|---|
| | {A01:{YEAR} / API1:{YEAR}} | {OWASP Top 10 {YEAR} / OWASP API Security Top 10 {YEAR}} |

This mapping is the entire standards scope of this plan. It is not a conformance assessment and not a certification.

---

> The gap register, sections 5 through 8 and 11, stays out of any public repository. It is a prioritized map of what is not protected yet.
