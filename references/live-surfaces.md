# Live Surfaces

Half of a system's security posture is not in the repository. It lives in the administrative consoles of the platforms the system runs on, and a code reader never sees it. Whether row security is on, whether public sign-up is off, whether the default branch is protected, whether preview deployments are password-protected, whether a spend cap exists: the code is silent on all of it.

This reference is the procedure for going and looking.

---

## 1. The principle

A verified setting beats a confident guess.

Platform defaults change between releases, and they are frequently open, because an open default is what makes the first five minutes of a tutorial work. The repository shows intent. The dashboard shows reality. The two disagree more often than teams expect: a migration that enabled a policy was reverted, a toggle was flipped during a debugging session and never flipped back, a plan change silently dropped a protection, a setting was configured on the staging project and never on production.

When the session has access, read the real value. When it does not, say so and hand the check to the user, rather than assuming the default is safe.

Reading a setting is verification and nothing else. Section 5 covers what changes when you want to alter one.

---

## 2. Tool preference order

Work down this list and stop at the first rung that reaches the surface.

1. **A connected MCP server for that provider.** Fastest, structured, and the answer comes back as a value rather than a screenshot. Check what is actually connected in the session before concluding there is nothing.
2. **The provider CLI**, when it is installed and authenticated. `gh`, `supabase`, `wrangler`, `vercel`, `aws`, `gcloud`, `az`, `stripe`, `flyctl`, and their equivalents read configuration without a browser.
3. **Authenticated browser automation**, for anything that exists only in a dashboard UI. Several of the highest-value settings, notably preview protection, spend caps, and organization-wide two-factor enforcement, often have no usable API at all.
4. **Ask the user to read the screen and report back.** Name the setting, say what value you expect, ask for the value they see.

Never guess while any of the first three is available. A guess recorded as a finding is worse than an unknown recorded as pending, because nobody ever re-checks a finding.

---

## 3. Confirm the account first

Before the first read against any provider, confirm which account, organization, or project is the intended target.

One person routinely holds several unrelated accounts on the same provider: a personal one, an employer's, a client's, a dormant one from a project that ended. The credentials loaded in a session are simply whichever were used last. They are not evidence of intent. Reading the wrong company's infrastructure is a privacy incident, and changing it is worse.

- Ask once per provider, before the first call, not before the first write.
- Where the tool can name the identity, name it back and confirm against that: the account email, the organization slug, the project reference, the cloud account number. A vague yes is not a confirmation.
- When the project on disk carries an identifier, a project reference in an environment file, a git remote, a site identifier in a deploy config, propose that as the target and ask for agreement.
- An account confirmation is not a project confirmation. Where one account holds several projects, confirm the project as well.

---

## 4. Surfaces

For each surface: what to verify, what wrong looks like, and which layer of layer-playbooks.md owns it. The providers named are examples. The same questions apply to whatever equivalent the project actually uses.

### Source control (GitHub, GitLab, and equivalents)

| Verify | Wrong looks like | Layer |
|---|---|---|
| Branch protection on the default branch, with force push and deletion blocked | No rule at all, or a rule that administrators bypass silently | 8 CI/CD |
| Review required before merge, and required checks actually listed | Protection enabled with zero required reviewers and zero required checks | 8 CI/CD |
| Secret scanning and push protection enabled | Off, or on for the organization but not for this repository | 9 secrets |
| Default workflow permissions for the pipeline token | Read and write granted to every workflow by default | 8 CI/CD |
| Third-party actions pinned to an immutable commit reference | A moving tag such as `@v4`, or an unrestricted allowlist of publishers | 8, 10 supply chain |
| Deploy keys, machine users, and webhook endpoints inventoried | A write-capable key nobody recognizes, or a webhook posting to a dead host | 9 secrets |
| Outside collaborators and their permission level | A contractor from a finished engagement still holding write access | 9 secrets |
| Two-factor enforced organization wide | Enforcement recommended but not required | 4 identity |
| Repository visibility, and whether it was ever public | Public repository whose history was never scanned | 11 public exposure |

### Managed database and backend platforms (Supabase, Firebase, and equivalents)

| Verify | Wrong looks like | Layer |
|---|---|---|
| Row or document security enabled on every table, collection, and bucket | One table created after launch with rules never enabled | 3 data store |
| Policies scoped per owner or per tenant | A policy granting read to any authenticated caller | 3 data store |
| Public sign-up state on the identity module | Open registration on a product that onboards by invitation | 4 identity |
| Storage bucket visibility and per-object rules | A public bucket holding user uploads | 3 data store |
| Realtime or subscription exposure per table | Realtime broadcasting a table whose rules were the only filter | 3 data store |
| Client key lifetime and rotation date | An anonymous key valid for a decade and never rotated | 9 secrets |
| Service or admin key never present in a client bundle or repository | Privileged key in a build-time variable prefixed for client exposure | 9 secrets |
| Network restrictions on direct database connections | Database port reachable from the whole internet | 5 infrastructure |
| Multi-factor required for organization members | Owner account with password only | 4 identity |
| Point-in-time recovery or scheduled backups, and a tested restore | Backups on the plan's minimum retention, never restored once | 3 data store |

### Hosting and edge (Cloudflare, Vercel, Netlify, and equivalents)

| Verify | Wrong looks like | Layer |
|---|---|---|
| TLS mode end to end, and minimum protocol version | Flexible or partial encryption to the origin, or TLS 1.0 still accepted | 6 edge |
| Strict transport security enabled, with a long max-age | Header absent, or max-age set to a few minutes and forgotten | 6 edge |
| Preview, branch, and deploy hostnames protected | Every branch deploy publicly reachable with production data behind it | 6 edge |
| Firewall, WAF, and rate limiting rules present and enabled | Rules written in a disabled state, or scoped to a hostname no longer used | 2 backend, 6 edge |
| Bot and abuse controls on login and expensive endpoints | Nothing between a scripted client and the authentication endpoint | 2 backend |
| Cache rules on authenticated and private paths | A private response cached at the edge and served to the next visitor | 6 edge |
| Environment variable scope per environment, and which are exposed to the client bundle | A server secret carrying a client-exposed prefix | 9 secrets |
| Spend limits, usage caps, and billing alerts | Unlimited metered usage on a consumption plan | 5, blast radius |

### Identity providers (Auth0, Clerk, Cognito, and equivalents)

| Verify | Wrong looks like | Layer |
|---|---|---|
| Session and access token lifetime | Access tokens valid for days on a product handling money | 4 identity |
| Refresh token rotation and server-side revocation | A refresh token that survives password change and logout | 4 identity |
| Multi-factor available to users and enforced for administrators | Available in the plan, enabled for nobody | 4 identity |
| Allowed callback, logout, and redirect URLs | A wildcard entry, or a leftover localhost or preview host in production | 2 backend, 4 identity |
| Password policy and breached-password protection | Minimum length of six and no compromised-credential check | 4 identity |
| Enumeration behavior on login, registration, and recovery | Distinct responses that confirm whether an address exists | 4 identity |
| Brute force and stuffing protection, per account and per address | Detection enabled in monitor-only mode | 4 identity |

### Observability (Sentry, PostHog, Datadog, and equivalents)

| Verify | Wrong looks like | Layer |
|---|---|---|
| Personal data scrubbing on ingest, including request bodies and headers | Default scrubbing disabled to make debugging easier, then left off | 7 observability |
| Session replay masking of inputs and text | Replay recording a checkout or an admin panel unmasked | 7 observability |
| Data retention period, stated and bounded | Maximum retention on the plan because nobody chose | 12 privacy |
| Spike protection and event quotas | One broken deploy able to bill the full quota in an hour | 7 observability |
| Member list, roles, and two-factor enforcement | Former contractor with access to a full map of the system | 4 identity |
| Which client keys are public by design, and what they authorize | A write-capable project token treated as a public key | 9 secrets |

### Payments (Stripe and equivalents)

| Verify | Wrong looks like | Layer |
|---|---|---|
| Webhook signing secret configured, and the endpoint verifying it | Endpoint live and trusting the payload unverified | 13 payments |
| Webhook endpoint health, event selection, and retry state | Endpoint failing silently while entitlements go ungranted | 13 payments |
| API key scope, and restricted keys where the provider offers them | One unrestricted secret key used by every service | 9 secrets |
| Live and test keys separated per environment | A live key in the staging environment | 9 secrets |
| Fraud and risk rules enabled | Default rule set never reviewed on a product taking card payments | 13 payments |
| Protection on payout destination changes | Bank details changeable with a session alone, no step-up | 13 payments |

### Registrar and DNS

| Verify | Wrong looks like | Layer |
|---|---|---|
| CAA record present, with the `iodef` contact set to a role address | No CAA, or a contact pointing at one person's personal mailbox | 6 edge |
| DNSSEC enabled at the registrar and the zone | Signed at one side only, which is the same as unsigned | 6 edge |
| Registrar transfer lock and auto-renew, with a valid payment method | Auto-renew on an expired card and a billing contact nobody reads | 6 edge |
| SPF ending in a hard fail, covering every sending vendor | `~all`, or a record missing the vendor that sends transactional mail | 6 edge |
| DKIM signing active on every outbound stream | Signed on the main stream, unsigned on the marketing one | 6 edge |
| DMARC at an enforcing policy, with an aggregate report address | `p=none` left running as a permanent state | 6 edge |
| Every record points at a resource still owned | A CNAME aimed at a released bucket or a deleted platform app | 6 edge |

### Cloud IaaS (AWS, GCP, Azure)

| Verify | Wrong looks like | Layer |
|---|---|---|
| Multi-factor on the root or owner account, hardware key where possible | Root protected by a password in a shared vault | 4 identity |
| No access keys on the root or owner identity | A root access key created once for a script and never deleted | 9 secrets |
| IAM roles scoped to what each workload calls | A wildcard administrative policy attached to an application role | 5 infrastructure |
| Object storage buckets not publicly readable or writable | Public access blocked at the account level but overridden per bucket | 3 data store |
| Security groups and firewall rules with no rule open to the world | Administrative or database ports open to every address | 5 infrastructure |
| Audit logging enabled in every region in use, and retained | Logging on in the home region only | 9 secrets |
| Key rotation on customer-managed keys and long-lived credentials | Keys with no rotation and no owner named | 9 secrets |

### VPS and self-hosted providers

| Verify | Wrong looks like | Layer |
|---|---|---|
| Provider-level firewall default-deny, in addition to the host firewall | Provider firewall absent, everything resting on the host rules | 5 infrastructure |
| SSH key-only access, password authentication and root login disabled | Password login left enabled for a rescue that never happened | 5 infrastructure |
| Snapshot and backup schedule, stored outside the same blast radius | Snapshots in the same account and region as the instance | 5 infrastructure |
| Current public address of the origin | Address published in DNS while the edge is meant to be mandatory | 6 edge |
| Origin restricted to the CDN address ranges | Origin answering any client that knows the address | 5, 6 |

---

## 5. From reading to changing

Verification is read-only and needs no permission beyond the account confirmation in section 3. Changing a live setting is a different act, and it has its own sequence.

1. **Propose the exact change.** The setting by name, the current value you read, the target value, and what it does to users, developers, and cost. Not a category of hardening, one specific change.
2. **Get agreement on that specific change.** Approval of a plan is not approval of a toggle.
3. **Apply it.**
4. **Re-read the setting and confirm it took effect.** A dashboard toggle that appears to save can be rejected by a plan limit, overridden by an organization policy, or applied to a different environment than the one on screen.
5. **Record it.** Surface, setting, value before, value after, when, and who agreed. Section 7.

Anything irreversible, outward-facing, or billable is confirmed every time, even when a previous change in the same session was approved: credential rotation, deleting data, publishing, enabling a paid tier, changing live infrastructure.

When a change can lock someone out, and network restrictions, firewall rules, two-factor enforcement, and key rotation all can, confirm the recovery path exists before applying, not after.

Never bypass an authentication challenge or a second factor, including the user's own. When a dashboard asks the human to authenticate, stop and ask them.

---

## 6. When access is missing

**Ask for it before you write it off.** A surface you cannot reach is a surface you cannot secure, and the user is usually one connected tool or one read-only token away from closing that gap. Name the surface, say in one line what reaching it would let you verify, and offer every form that would work: a connected MCP server for that provider, a CLI they are already signed into, a browser session they are already logged into, a read-only token scoped to that one provider, or a screenshot of the single settings page in question. Ask for read access only. Verification never requires write, and changing a setting is a separate agreement (section 5).

Ask once, clearly, and take no for an answer. Do not stall the engagement waiting for credentials, and do not ask twice for the same thing in the same session.

If no MCP server, no CLI, and no authenticated browser session reaches a surface, do not silently skip it, and do not assume the default is safe. Convert it into work the user can do.

Write a short instruction that names the setting, says what it does in one sentence, says what the correct value is for this system, and says what to report back. Then mark the item **pending manual verification** in the coverage matrix, naming the surface and the owner. Pending is a legitimate status. Absent is a gap that survives.

Do not invent dashboard URLs or menu paths. Console navigation is reorganized constantly, and a wrong path costs the user more time than no path. Describe the setting by name and by what it does, so it is findable in a search box regardless of where the provider moved it.

---

## 7. Record what you touched

Keep one list for the whole engagement, covering both categories.

- **Every live change:** surface, setting, value before, value after, timestamp, and who agreed to it. This is what makes a rollback possible and what answers the question of what changed when something breaks an hour later.
- **Every artifact created during verification:** a test account, a probe record, a temporary firewall or WAF rule, a scratch bucket, a token minted to run a read. Each one is removed at the end, or deliberately kept with the reason written next to it.

A token minted for a check is a credential like any other. Revoke it when the check is done, or add it to the inventory in layer 9 with a scope, an owner, and a rotation date.

This list belongs with the private material described in operating-discipline.md, section 4. It names live settings and identifiers, so it does not go into the public repository.
