# Pre-Launch Gate

Two tiers. Tier 1 blocks the deploy. Tier 2 is required for the profile and the data class, and is tracked with a named owner and a date.

Mark each item Pass, Fail, Pending manual verification, or Not applicable with a reason. No blanks.

**Pending manual verification** means the control could not be verified because the surface was not reachable in this session. It carries the surface name, the reason access was missing, and an owner. It is not a pass and it is not a deferral: it means unknown. Anything still Pending when this gate runs gets raised again rather than passed silently.

**How this relates to MUST.** A MUST in the layer playbooks means the control is obligatory for this system, not that every one of them holds the first deploy. Tier 1 is the subset an automated attacker reaches immediately or that cannot be repaired later, and it is the only tier with veto power. The remaining MUST items sit in Tier 2: obligatory, dated, owned, and closed on a schedule agreed before launch. If a Tier 2 item has no owner and no date, it is not scheduled, it is skipped, and it goes back to Tier 1.

---

## Tier 1: blocking core

Every item here is something an automated attacker tries within the first hour of the system being reachable, or something that cannot be repaired after the fact. The deploy waits until all of them pass.

- [ ] Access rules enabled on every table, collection, and bucket, including anything added in the last week
- [ ] Rules deny by default and are scoped per owner or tenant, on read **and** on write
- [ ] Cross-tenant test passes: account A cannot read, update, or delete account B's records, verified with a real client credential against the real rules
- [ ] Every foreign key crossing a tenant boundary is enforced in the schema
- [ ] Privileged fields (role, plan, balance, verification, subscription state) are not writable by clients at the privilege level
- [ ] Multi-factor enforced on every administrative and infrastructure account
- [ ] Rate limits on authentication, on writes, and on anything metered, with the failure mode decided and written down per endpoint (deny on credential checks and paid calls, degrade to an in-process limiter elsewhere)
- [ ] Full history scanned with a secret scanner, not just the current state
- [ ] Built client bundle contains no private credential
- [ ] Anything ever exposed has been rotated, not merely removed
- [ ] Encryption enforced, including on the bare domain, not only the primary hostname
- [ ] Platform preview and branch hostnames blocked or password-protected
- [ ] Deploy publishes an explicit artifact list, verified by requesting internal paths from outside
- [ ] No known high or critical vulnerabilities in production dependencies, or each documented with a reason and date
- [ ] Amounts decided server-side or by the provider, never accepted from the client
- [ ] Webhooks verify signature, reject replays, and are idempotent, verified by replaying one
- [ ] Spend caps and usage alerts configured at every metered provider
- [ ] Backups exist, and a restore has actually been performed once

---

## Tier 2: required for the profile and data class

Scheduled, not skipped. These do not hold the first deploy. Each one gets a named owner and a target date at the same session where Tier 1 is signed off, and the dates go on the calendar before the deploy happens.

### Identity

- [ ] Passwords hashed with a modern memory-hard function, if passwords exist
- [ ] Sessions revocable, and revocation verified to take effect immediately
- [ ] Token lifetimes are intentional, and rotation is known to work
- [ ] Recovery flow is as strong as the login flow
- [ ] Brute force throttled on login and on recovery
- [ ] No seeded or default credentials reachable from the network

### Application

- [ ] Every protected route rejects an anonymous caller (whole route table swept, not sampled)
- [ ] Every protected route rejects a valid session belonging to a different account
- [ ] Privilege escalation attempt fails for every client-visible representation of role or plan
- [ ] Server-side validation on every input, with size limits
- [ ] Uploads validated by real file content, stored outside the web root or in a private bucket, served without execution, metadata stripped
- [ ] Errors returned to clients are generic; no stack traces, database messages, or internal paths

### Secrets

- [ ] Secrets live in the platform secret store, scoped, and separated per environment
- [ ] Push protection and secret scanning enabled on the repository

### Edge and transport

- [ ] Strict transport enabled
- [ ] Transport, content-type, and framing headers present and enforcing, not report-only
- [ ] Content Security Policy deployed with a report endpoint, and a dated plan to switch it to enforcing
- [ ] Certificate issuance restricted, with a role address as contact
- [ ] Mail authentication configured if the domain sends mail

### Infrastructure (self-hosted profiles)

- [ ] Firewall default-deny, administrative access restricted by address
- [ ] Origin reachable only from the edge network
- [ ] Service runs unprivileged; no container holds the host control socket
- [ ] Remote access by key only, no direct root login
- [ ] Operating system security patch channel active and applying on its own
- [ ] Reverse proxy, runtime, and base images pinned by digest, with feature and major-version upgrades out of automatic mode
- [ ] Alerts configured on load, connections, and error rate, with a real destination

### Pipeline

- [ ] Build actions pinned to immutable references
- [ ] Production deploy gated by review, no direct push
- [ ] Dependency and secret scanning run in the pipeline

### Dependencies

- [ ] Lockfiles committed, automated alerts enabled, with a named owner

### Observability

- [ ] No secrets or personal data reach logs, error reports, or analytics, verified by triggering a real error containing fake sensitive values
- [ ] Session replay masks input and text if it runs near personal data
- [ ] Alerts on authentication failures, authorization denials, and error spikes

### Money and integrations

- [ ] Entitlement granted only after provider confirmation, never on a client redirect

### Privacy

- [ ] Only necessary personal data collected, with retention defined
- [ ] Deletion and export paths work end to end, including analytics and backups
- [ ] Third-party processors documented
- [ ] Breach notification duty and its clock understood

### External view

- [ ] Public surface reveals no versions, internal paths, or infrastructure detail
- [ ] Sensitive paths return nothing real, confirmed by comparing response sizes against a path that does not exist
- [ ] Cache is not serving anything the origin no longer publishes
- [ ] Repository is private, or its history was scanned before it went public

---

## Sign-off

| Field | Value |
|---|---|
| Date | |
| Tier 1 items passed | |
| Tier 1 items failed, blocking | |
| Tier 2 items passed | |
| Tier 2 items open, each with owner and date | |
| Not applicable, with reason | |
| Test artifacts created and removed | |
| Decision | {go / no-go} |

Any failed Tier 1 item is a no-go until fixed or explicitly accepted in writing by the owner, with the reason recorded.

Tier 2 is scheduled, not skipped. An open Tier 2 item is acceptable at launch only while it carries a named owner and a date. A Tier 2 item with no owner or no date counts as a Tier 1 failure and blocks the deploy.
