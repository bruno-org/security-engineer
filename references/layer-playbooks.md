# Layer Playbooks

Thirteen core layers. Every engagement walks all of them. A layer that does not apply is recorded as Not applicable with a reason, never left blank. One conditional layer sits alongside them, in references/ai-surface.md, and applies only when the system ships model or agent features.

Each playbook has the same shape:

- **Decisions**: what must be chosen, with the safe default.
- **MUST**: blocking. Failure here is exploitable by an automated attacker or loses user data.
- **SHOULD**: expected for this profile and data class. Skipping is recorded with a reason and an owner.
- **MAY**: worth it as the system, team, or data class grows.
- **Acceptance check**: how to prove it holds.
- **Friction**: what the user or developer actually feels.

---

## 1. Frontend

The client is a display surface. It decides nothing that matters. Assume every line of it is read by the adversary, because it is: shipped JavaScript is public source code.

**Decisions.** Rendering model, where session state lives, what the bundle is allowed to contain.

**MUST**
- No secret, private key, service credential, or privileged token in the bundle, in build-time constants, or in client-visible configuration. Public identifiers meant to be public are fine, and are documented as such.
- No authorization decision that the server does not independently repeat. Hiding a button is user experience, never a control.
- Output encoding by default: render user-controlled content as text, not as markup. Any raw HTML insertion path is explicitly justified and sanitized with a maintained library.
- Session credentials stored where hostile script cannot read them. Prefer cookies marked http-only, secure, and same-site. Storing long-lived tokens in browser storage is a decision that requires justification. Choose the `SameSite` value deliberately rather than inheriting a framework default: `Lax` sends the cookie on top-level navigations and withholds it on cross-site subrequests and cross-site form posts, `Strict` withholds it on every cross-site entry including a link the user clicks, and `None` sends it on every cross-site request and requires `Secure`. Putting the session in a cookie is what creates the cross-site request obligation in layer 2, and no `SameSite` value discharges that obligation on its own.
- No source maps for private code in production, or restrict them to authenticated access.

**SHOULD**
- **A Content Security Policy that ends up enforcing.** Roll it out in the right order: ship `Content-Security-Policy-Report-Only` first, collect violations from real traffic, fix what breaks, then switch the header to `Content-Security-Policy`. Skipping the report-only stage breaks analytics, payment widgets, support chat, and embeds all at once, and the team reverts it within the hour, which leaves you with no policy at all. The failure to avoid is the opposite one: a policy that sits in report-only forever while everyone believes it is protecting them. Report-only is a stage, not a destination, so put a date on the switch.
- **Name the headers, do not gesture at them.** `Strict-Transport-Security` with a `max-age` of at least a year and `includeSubDomains`; `X-Content-Type-Options: nosniff`; `frame-ancestors` in the policy, with `X-Frame-Options: DENY` as the legacy fallback; `Referrer-Policy: strict-origin-when-cross-origin` so full paths and query strings stop leaking to third parties; `Permissions-Policy` to switch off camera, microphone, and geolocation you never use. Add `Cross-Origin-Opener-Policy` and `Cross-Origin-Resource-Policy` when the app handles anything worth isolating.
- Subresource integrity on any third-party script loaded from a shared network.
- Clickjacking protection: framing denied unless embedding is a product requirement.
- External links that open a new context marked to prevent opener access.
- **Message channels between browsing contexts are input.** Every `postMessage` handler checks the sender's origin and the message shape before acting on it, wildcard targets are never used to send sensitive data, and any object merged from client-supplied JSON rejects prototype keys. Service worker scope and cache are a persistence surface: a hostile script that registers one survives a page reload.
- Dependency count kept deliberately small. Every client dependency is a script that runs in your users' browsers with full access to their session.

**MAY**
- Nonce-based script policy instead of allowing inline scripts, once the build supports it.
- Client-side integrity monitoring for payment or credential pages.

**Acceptance check.** Search the built artifact for credential-shaped strings and confirm only intended public identifiers appear. Load the deployed page and confirm the policy header is enforcing. Attempt to render a scripted payload through every user-content path and confirm it displays as text.

**Friction.** Rank 1, invisible, with one exception: a strict script policy can require a build change. That cost lands on developers once, not on users.

---

## 2. Backend and API

Where every real decision lives.

**Decisions.** Framework, validation approach, session verification, error contract, tenancy model.

**MUST**
- Identity is derived from a verified session or token on the server. Never from a request body, a header the client controls, a query parameter, or a client-supplied identifier.
- Authorization is checked on every handler, including the ones that seem harmless. Default deny: a route without an explicit rule is closed, not open.
- **Authorization runs where the work happens, not in a layer in front of it.** Edge middleware, route guards, and shared layouts are user experience and routing. They get bypassed by direct calls, by path normalization tricks, and by framework quirks, and some do not run on every navigation. Put the decision in the handler, the service, or the database function that actually performs the action.
- Object-level ownership is verified for every access by identifier. See app-defaults.md, Default 3.
- **State-changing requests carry proof of intent that a cross-site context cannot produce.** Any endpoint authenticated by an ambient credential the browser attaches automatically, meaning a cookie, is reachable by any site the user visits. Same-site cookie attributes plus a synchronized token, or an equivalent framework mechanism, closes it. Two traps: a custom header alone only defends against an attacker working through a victim's browser, and is forged freely by anyone calling the API server-side with a public key; and requests that qualify as simple, notably form and multipart posts, never trigger a preflight, so nothing checks that header before the request lands.
- Input validated on the server: type, size, range, format, and allowed values, using a schema, before it touches business logic or the database.
- Database access parameterized. No query built by string concatenation with user input.
- **Regular expressions applied to user input run in linear time, or carry a length cap and a timeout.** A single crafted string against a backtracking pattern is the cheapest way to burn a core.
- **Redirect destinations come from an allowlist, or are validated relative paths.** A `next` or `returnTo` parameter passed through to a location header turns your domain into a phishing launcher and leaks authorization codes on identity callbacks.
- **Values from user input never flow into response headers unfiltered.** Strip carriage returns and newlines from anything reaching a location, cookie, or content disposition header.
- Errors returned to the client are generic. Stack traces, database messages, and internal paths never leave the server. They go to logs.
- **Exception text is never persisted as application data.** Store a categorical error code, not the raw message. A message column reaches an admin panel, an export, or a support view later, and it carries whatever personal data happened to be in the failing payload, with no legal basis and no retention.
- **Uniqueness and capacity invariants are enforced by the database, not by check-then-write in application code.** Unique constraints, transactions, row locks, or a single conditional atomic update. Two identical concurrent requests must produce one effect. Read the value, decide, then write is a race, and the gap between the read and the write is where double bookings, double spends, and duplicate accounts live.
- Rate limits on authentication, on writes, and on anything that costs money per call.
- **Decide the failure mode per endpoint, and write the decision down.** When the limiter's backing store is unreachable, denying everything turns a cache outage into a full outage, and that store becomes a single point of failure for the whole product. Fail closed on the endpoints where an unlimited call is genuinely dangerous: login and other credential checks, payment and payout, invitation and mail sending, anything that bills per call. Fail open elsewhere, but degrade to an in-process limiter rather than to no limit at all, and alert when that happens. A blanket fail-closed rule is how a security control becomes the cause of the incident.
- **The identifier the limiter counts must not be forgeable.** Client-supplied forwarding headers are attacker-controlled unless the proxy directly in front overwrites them. Read the header your own edge sets, and make the proxy replace rather than append. The same warning applies to address allowlists, bans, and audit records.
- Webhooks from third parties verify the provider signature before trusting a single field, and reject replays.
- **Signature, token, and code comparisons are constant-time.** Byte-by-byte comparison that returns early on the first mismatch leaks the correct value for webhook signatures, reset tokens, one-time codes, and API keys.
- **User-controlled content going to a surface you do not render is still an injection sink.** Email bodies, calendar invitations, chat webhooks, generated documents, and exports run outside your origin and outside your content policy. Encode for the destination format.
- Server-side requests to user-supplied destinations are blocked or allowlisted, so the server cannot be used to reach internal addresses.

**SHOULD**
- Idempotency keys on operations that create or move money or state.
- **Multi-step operations report success only when every step the user's result depends on succeeded.** A response that says success while carrying a nested failure gets treated as success by the client, and an attacker who induces the external failure on purpose creates records that exist on your side and nowhere else. Roll back, or mark the record incomplete and tell the client the real state.
- Explicit method handling: routes answer only the verbs they implement.
- Cross-origin rules that name real origins. No wildcard on authenticated endpoints, no development origins in production.
- Request size caps and timeouts on every endpoint.
- Structured audit logging on privileged and money-moving actions, with the actor, the target, and the result. **Log denied attempts, not only successful ones.** A compromised privileged account produces successes that look ordinary. An account probing for privilege produces denials, and that is the signal that arrives before the damage.

**MAY**
- A shared authorization policy layer, once route count makes per-handler checks hard to review.
- Tenant isolation at the connection or schema level for higher data classes.

**Acceptance check.** For each protected route, call it with no session, with a valid session for a different account, and with a tampered client-side role claim. Only the correct case succeeds. Confirm the failure mode is written down per endpoint: the endpoints classified fail closed deny when the backing store is unavailable, and the rest degrade to an in-process limiter and raise an alert rather than dropping to no limit.

**Friction.** Rank 1. Correct server checks are invisible when the client is honest.

---

## 3. Data store

The last line that holds when application code is wrong. Never rely only on the application layer.

**Decisions.** Engine, tenancy model, whether clients ever talk to the database directly, encryption, backups.

**MUST**
- Access rules enabled and deny by default on every table, collection, or bucket, on the day it is created. Not later, not before launch, at creation. Platforms that ship rules off, or in an open test mode that expires, are the single most common cause of mass data exposure.
- Every rule is owner-scoped or tenant-scoped. A rule that grants blanket read or write to any authenticated caller is a rule that leaks across customers.
- Any client that talks to the database directly is treated as hostile. If the browser holds a database key, then the database rules are the only control, and they carry the entire weight.
- Privileged keys that bypass rules exist only on the server. They never reach a client, a build, or a repository.
- **Row security enabled in its forcing variant where the engine offers one.** In Postgres that is `ALTER TABLE ... FORCE ROW LEVEL SECURITY`, because a table owner bypasses its own policies otherwise, and the migration role is usually the owner.
- **Database functions that run with the definer's privilege pin their search path and fully qualify every object they touch.** In Postgres the default is `SECURITY DEFINER` with `SET search_path = ''`, which forces every referenced object to carry its schema, since nothing resolves unqualified under an empty path. Leaving `public` in the path reopens the resolution the pin exists to close, because any role that holds `CREATE` there can plant a matching object. Without both, a caller who controls schema resolution points the function at a table they own, and the function becomes a privilege escalation path. Such a function validates its own arguments and re-checks the caller's identity rather than trusting that a caller reached it legitimately, and it is owned by the least-privileged role that works.
- **A database function reachable remotely is a public endpoint.** Auto-generated REST and RPC layers publish functions to the internet, so `EXECUTE` is revoked from the anonymous role by default and granted deliberately, one function at a time. The authorization duty is identical to an HTTP handler's.
- Personal, financial, and health data encrypted at rest, with transport encryption enforced.
- Backups exist, are restorable, and are stored outside the web root and outside the primary blast radius. An untested backup is a hope.
- Unused platform modules are switched off explicitly: open sign-up when the product has no public registration, public storage buckets, real-time subscriptions, anonymous access. Defaults are frequently open.

**SHOULD**
- Least-privilege database roles per component. The reader does not write, the worker does not read customer records it does not need.
- Column or field-level restriction on the most sensitive attributes.
- Soft delete plus retention policy rather than immediate destruction, where regulation allows. Keep the window short and bounded, and treat the flagged row as recovery from accidental deletion. An erasure request needs the separate path described in layer 12.
- Migrations reviewed for grants and for rules, since a migration is the usual way a rule quietly disappears.

**MAY**
- Field-level encryption for the highest-sensitivity attributes.
- Separate database instances per tenant for regulated data.

**Acceptance check.** Using only a client-side key and no privileged credential, attempt to read and write a record belonging to another account, and attempt to list a table that should be closed. All must be denied. Repeat after every migration.

**Friction.** Rank 1, invisible to end users. Costs developer time once, at table creation, which is why it must happen at creation.

---

## 4. Identity and authorization

**Decisions.** Who authenticates, how sessions are represented, how roles are stored, how recovery works, how sessions end.

**MUST**
- **Passwords, if used, stored with a purpose-built password hashing function, never encrypted.** Argon2id is the preferred choice for new systems, at 19 MiB of memory, 2 iterations, and parallelism 1 as a floor. scrypt is acceptable. bcrypt at a cost factor of 10 or higher is also acceptable and does not warrant an urgent migration, which matters because bcrypt is what most installed systems already run. Fast general-purpose digests are not password hashing: MD5, SHA-1, and SHA-256 alone are guessed at billions of candidates per second on rented hardware, salted or not. Record the cost parameters next to the code that sets them and review them as hardware improves.
- **Identifiers a human types are normalized and canonicalized before any comparison and before the uniqueness check.** Email addresses, usernames, tenant slugs, and invitation codes: apply Unicode normalization (NFKC), case fold, trim surrounding whitespace, then store and index that value. The unique constraint applies to the normalized column, never to the raw input. Without this, two visually identical accounts coexist, a homoglyph lookalike impersonates a real user in an approval flow, and the unique constraint is bypassed by a variant that differs only in encoding or case.
- Sessions verifiable and revocable on the server. A token that cannot be revoked is a permanent key.
- Token lifetime proportional to risk. Long-lived credentials are a design smell. A client-side key with a lifetime measured in years is a decision to be made deliberately, if at all, and rotated on a schedule.
- Roles and entitlements stored server-side and read from the server on every decision. Never trusted from a client-supplied claim the client can edit.
- Multi-factor authentication available for users and enforced for administrators.
- Account recovery paths as strong as the login path. Recovery is where accounts are actually taken.
- Enumeration handled deliberately: registration, login, and recovery responses do not reveal whether an address exists, unless the product requires it and the decision is recorded.
- Brute force and credential stuffing throttled: per-account and per-address limits, with lockout or progressive delay.

**SHOULD**
- Single sign-on or a managed identity provider for administrative access.
- Session invalidation on password change, on role change, and on logout everywhere.
- Step-up confirmation for destructive or high-value actions, rather than blanket friction.
- Separate administrative identity from customer identity, so an ordinary account cannot become an administrator through the ordinary flow.

**MAY**
- Hardware-key second factor for the highest-privilege accounts.
- Anomaly detection on login geography and device.

**Acceptance check.** Attempt to elevate privilege by editing every client-visible representation of role. Confirm a revoked session stops working immediately. Confirm password reset invalidates existing sessions.

**Friction.** Multi-factor is rank 2, felt once by administrators. Step-up is rank 3, felt rarely. Neither belongs on ordinary browsing.

---

## 5. Infrastructure and network

Applies to any profile with a server, container, or virtual machine. Managed serverless profiles cover much of this, and the parts that remain are noted in stack-profiles.md.

**Decisions.** Where it runs, what is exposed, how it is deployed, how it recovers.

**MUST**
- Default-deny inbound. Only the ports the product needs, and administrative access restricted to known addresses.
- Provisioning order is defensive: firewall first, runtime second, proxy third, application last. Publishing the application before the firewall exists creates a window that automated scanners find within minutes.
- Remote administrative access by key only, root or administrator login disabled, brute-force protection active.
- The service runs as an unprivileged user, not as root.
- The origin accepts traffic only from the edge network in front of it. Otherwise the edge is decorative, since the origin address is discoverable through historical records and certificate logs.
- No container is granted access to the host control socket. That is equivalent to handing over the whole machine.
- Secrets are not baked into images or passed as build arguments, because they persist in image layers.
- **Security patches apply automatically. Feature and major-version upgrades do not.** These are different risks and deserve opposite defaults. Leave the operating system's automatic security channel enabled, because an unpatched known vulnerability is the most common way systems are taken, and a controlled maintenance window that depends on someone remembering is a window that never opens on a small team. Separately, pin the major version of the reverse proxy, the runtime, and anything else whose upgrade can take the service down, ideally by immutable digest, and move those versions deliberately with a rollback ready. The failure being avoided here is an unattended feature upgrade installing a broken release by itself at three in the morning, not the security patch that closes a published vulnerability.

**SHOULD**
- Base images pinned by digest, scanned before use, rebuilt on a schedule.
- Container capabilities dropped to the minimum, privilege escalation disabled, filesystem read-only where possible.
- **Kernel network defaults raised on anything that takes real traffic.** Enable SYN cookies (`net.ipv4.tcp_syncookies=1`), then raise the SYN backlog (`net.ipv4.tcp_max_syn_backlog`, 8192 or more), the accept queue (`net.core.somaxconn`, 8192 or more, with a matching `backlog=` on the proxy's listen directive, which otherwise caps it back down), and the device backlog (`net.core.netdev_max_backlog`, 16384 or more). Where a stateful firewall sits in the path, raise `net.netfilter.nf_conntrack_max` as well, because that table fills long before the interface saturates.
- **Open file descriptor limit for the serving process set to roughly 65000 soft and hard, in all three places.** The container runtime configuration (`ulimits: nofile` in compose, or `--ulimit nofile=65535:65535`), the service manager unit (`LimitNOFILE=65535` in the systemd unit), and the host limits configuration (`/etc/security/limits.conf` plus `DefaultLimitNOFILE=` in `/etc/systemd/system.conf`). Setting one and assuming it took effect is the usual mistake, since the lowest limit in the chain wins and the default of 1024 is a hard ceiling on concurrent connections.
- Backups and snapshots automated and restore-tested.
- Monitoring with alerts on proxy processor load, connection counts, and half-open connections. Without alerts, an attack is discovered when the service is already down.

**MAY**
- Infrastructure as code, so the hardened state is reproducible rather than remembered.
- File integrity monitoring on the served directory.
- A separate bastion for administrative access.

**Acceptance check.** From an address outside the edge network, attempt to reach the origin directly. It must refuse. Confirm the running process is unprivileged and the firewall default is deny.

**Friction.** Rank 1 for users, rank 2 for the operator once, at setup.

---

## 6. Edge: CDN, TLS, DNS, email

**Decisions.** Whether an edge network sits in front, which hostname is canonical, how mail is authenticated.

**MUST**
- Encryption in transit everywhere, including the bare domain, not only the primary hostname. A bare domain that answers only unencrypted and redirects can be intercepted on hostile networks.
- Strict transport security enabled.
- One canonical hostname. Platform-provided preview hostnames are blocked or password-protected, because they bypass every rule written for the canonical host.
- Certificate issuance restricted by policy record, meaning a CAA record naming the authorities allowed to issue, and the `iodef` contact on that record is a role address, not someone's personal mailbox.
- Mail authentication configured when the domain sends mail: SPF ending in a hard fail (`-all`), DKIM signing on every outbound stream including the ones your vendors send, and DMARC at an enforcing policy (`p=reject`) with an aggregate report address (`rua=`). An unprotected domain is spoofed and burns the sender reputation.
- **Every DNS record points at a resource you still control, and the record is deleted at the moment the resource is deprovisioned.** A CNAME or ALIAS left aimed at a released bucket, a deleted platform app, or an unclaimed vendor tenant lets whoever claims that name next serve content on your hostname, obtain a valid certificate for it, inherit cookie scope from the parent domain, and send mail as you.

**SHOULD**
- Domain registry signing (DNSSEC) enabled, plus registrar transfer lock and multi-factor on the registrar account. Auto-renewal on, with a payment method that has not expired and a billing contact more than one person reads: an expired domain hands identity, mail, and certificates to the next buyer, and it requires no exploitation at all.
- Subdomain inventory reviewed on a schedule against what is actually deployed, including hostnames that appear in public certificate transparency logs and never appeared in the zone file you maintain by hand.
- Denial of service protections active, with a documented, fast way to raise defenses under attack.
- Caching rules reviewed so that private or non-public files can never be cached and served publicly.
- Certificate transparency monitoring, so unexpected certificates are noticed.

**MAY**
- Preload registration for strict transport.
- Edge rules that block unused request methods and known hostile patterns.

**Acceptance check.** Request the bare domain and the canonical host over encrypted transport, confirm both answer correctly. Request the platform preview hostname, confirm it is blocked or protected. Resolve the CAA, SPF, DKIM, DMARC, and DNSSEC records and confirm each matches the intended policy, in particular that DMARC reads `p=reject` and SPF ends in `-all`.

**Friction.** Rank 1.

---

## 7. Observability

Telemetry is a data flow leaving your system. Treat it as such.

**MUST**
- No secrets, tokens, passwords, or full personal records in logs, error reports, or analytics events. Scrub before send.
- Session replay and screen recording tools configured to mask input fields and text by default when they run anywhere near personal data.
- Client-side telemetry keys treated as public, because they are. Nothing sensitive is authorized by them.
- Log retention bounded and stated.

**SHOULD**
- Alerts on authentication failure spikes, authorization denials, and error rate changes. Collecting without alerting means finding out late.
- Personal data filtered out of URLs before they reach analytics, since identifiers and tokens routinely ride in query strings.
- Access to observability dashboards restricted and multi-factor protected. They contain a detailed map of the system.
- **Telemetry does not instrument its own transport.** Wrapping `window.fetch` or `XMLHttpRequest` globally to report failed requests builds a feedback loop: the report fails, the wrapper reports the failure, that report fails. One backend outage becomes a self-inflicted flood from every open tab and an oversized invoice from the telemetry provider. Use the platform's observation interfaces instead, meaning `PerformanceObserver` with `resource` entries for request timing and the `error` and `unhandledrejection` events for exceptions. Exclude the telemetry host from whatever instrumentation remains, then sample and rate limit client-side error reporting so a single broken deploy cannot bill you per user per second.

**MAY**
- Separate projects per environment, so development noise cannot poison production signal.
- Anomaly alerting on data export volume.

**Acceptance check.** Trigger a handled and an unhandled error containing a fake credential and a fake personal record. Confirm neither value appears in the destination tool.

**Friction.** Rank 1.

---

## 8. CI/CD and pipeline

The pipeline has more privilege than most of the application, and receives a fraction of the scrutiny.

**MUST**
- The deploy publishes an explicit artifact, an allowlist of what ships. Deploying the working directory publishes tests, documentation, configuration, lockfiles, and internal notes, which together hand an attacker the map.
- Pipeline credentials are scoped to the single job that needs them, and are not exposed to builds triggered by outside contributors.
- Third-party build actions pinned to an immutable reference, not to a moving tag. A moving tag is code you did not review executing with your deploy credentials.
- Secrets provided by the platform's secret store, never in the workflow file, never echoed into logs.
- Production deploys are gated: protected branch, review required, and no direct push.

**SHOULD**
- Dependency and secret scanning run in the pipeline, blocking on high severity.
- Build reproducible from a clean checkout, so a compromised local machine cannot alter what ships.
- Separate credentials per environment. A staging key must not open production.

**MAY**
- Signed artifacts and provenance attestation.
- Automatic rollback on health check failure.

**Acceptance check.** Read the published artifact listing and confirm it contains only intended files. From an unauthenticated client, request several internal file paths and confirm none return real content.

**Friction.** Rank 2, developers only.

---

## 9. Secrets

**MUST**
- Ignore rules present in the first commit, before any secret could enter. Retrofitting is how history gets polluted.
- Secrets live in the platform secret store or environment configuration on the server side. Never in the repository, never in the client bundle, never in image layers, never in a shared document or chat.
- Every secret is scoped to the least privilege that works, and separated per environment.
- A secret that has ever been committed, pasted publicly, or shown on a screen is treated as compromised: rotate first, clean history second. Cleaning without rotating accomplishes nothing, because bots harvest continuously.
- Push protection and secret scanning enabled on the repository host.
- **Platform account hygiene, applied to every provider that can deploy, read data, or spend money.** That list is the repository host, the hosting and cloud accounts, the database platform, the payment provider, the mail sender, the registrar, and the CDN. Provider audit logging is enabled and retained for a stated period on each, because without it the question "how would we notice a breach" has no possible answer. Every platform API token is inventoried with its scope, its owner by name, and its rotation date, and is scoped to the minimum that works.

**SHOULD**
- Membership of every platform account reviewed on a schedule, with access revoked at offboarding rather than at the next review. Deploy keys, machine users, and webhooks are reviewed in the same pass, since they outlive the person who created them and carry no login to disable.
- A rotation schedule with a named owner, and rotation rehearsed at least once so it is known to work.
- Pre-commit scanning locally, so the block happens before the push.
- An inventory of every credential, what it opens, and who holds it.

**MAY**
- A managed vault with dynamic short-lived credentials.
- Automatic rotation on personnel change.

**Acceptance check.** Scan the entire history, not just the current state, with a secret scanner. Confirm the built client bundle contains no private credential.

**Friction.** Rank 1 to 2.

---

## 10. Dependencies and supply chain

The most common entry point for the automated attacker.

**MUST**
- Lockfiles committed, versions pinned.
- Automated vulnerability alerts enabled, with a named owner and a stated response window.
- No dependency added without a look at its maintenance status, its download-time scripts, and its transitive weight. A package that runs code on install is a code execution path.
- Client-side third-party scripts minimized and pinned. A script loaded from a shared network runs with full access to your users' sessions.

**SHOULD**
- Scheduled update cadence, so patching is routine rather than an emergency.
- Container and image scanning if containers are used.
- A software bill of materials for regulated or enterprise contexts.

**MAY**
- Vendoring or an internal registry mirror for critical dependencies.
- Allowlisting which packages may be installed.

**Triaging what the scanner returns.** A scanner hands back a queue, not a plan. Sorted by severity alone that queue never empties, the team stops reading it within a month, and the one advisory that mattered sits behind twenty that did not. Order it by four questions, in this order, and write the answer next to each item:

1. **Is it being exploited right now?** The known exploited vulnerabilities catalogue published by CISA is the shortest list that matters, because everything on it has confirmed exploitation in the wild rather than a theoretical score. Fetch the catalogue and check your advisory identifiers against it rather than recalling what is on it. A hit jumps the whole queue, whatever its severity number says, and is handled today.
2. **Can the vulnerable code be reached from this system?** An advisory in a package that ships to production, on a code path the application actually calls, is a different object from the same advisory in a build-only dependency or in a function nobody imports. Say which one it is. Unreachable does not mean dismissed, it means scheduled.
3. **How likely is the attempt in the open?** Severity describes the worst case if it is exploited. The exploit prediction score published for each identifier estimates whether anyone is trying. High severity with negligible probability on an unreachable path is a scheduled upgrade. Medium severity on a reachable path with a public exploit is this week.
4. **Does a fix exist, and can you take it?** Frequently the fix lives in a transitive dependency your direct one has not adopted yet, so the choice is an override, a pin, a replacement, or a documented wait. When no fix exists at all, the outcome is a mitigation with an owner and a revisit date, never a silent exception.

**Suppressions expire.** Every accepted advisory carries the reason, the owner, and the date it gets looked at again. A suppression with no expiry outlives everyone who understood why it was safe, and it is indistinguishable from a hole nobody noticed.

**Acceptance check.** Run the vulnerability scanner and show the queue after triage: nothing that appears on the known exploited catalogue, nothing reachable in production at high or critical severity, and every remaining item carrying a reason, an owner, and an expiry date. Confirm the scan runs on a schedule as well as on commit, since advisories land for code nobody touched.

**Friction.** Rank 2, developers only.

---

## 11. Public exposure

What the project reveals on purpose, and by accident.

**MUST**
- Repository private until its history has been scanned and reviewed. Public is a one-way door: assume anything ever pushed is permanently public.
- No internal architecture detail, version number, infrastructure address, or environment content in public documentation, issues, posts, screenshots, or recordings.
- Version banners suppressed on responses and error pages.

**SHOULD**
- A media checklist before publishing screenshots, recordings, or live sessions: close authenticated panels, clear terminal history, replace real identifiers with fake ones, blur sensitive regions, check reflections, strip image metadata.
- A security contact path, so a finder has somewhere to report.
- Share outcomes and lessons publicly, not versions, addresses, and configuration.

**MAY**
- A published vulnerability disclosure policy.

**Acceptance check.** From an unauthenticated session, retrieve the public surface and confirm no version, internal path, or infrastructure detail is disclosed.

**Friction.** Rank 1.

---

## 12. Privacy and compliance

Design constraint, not paperwork at the end.

**MUST**
- Collect the minimum that the feature actually needs. Every extra field is permanent liability.
- A lawful basis and a stated purpose for personal data, with retention periods defined at design time.
- Deletion and export paths that actually work, including in backups and in third-party processors.
- **Soft delete and erasure are two different mechanisms, and layer 3 recommends only the first.** A flagged row is operational recovery from accidental deletion: keep the window short and bounded, 30 days is a common choice, then purge on a scheduled job rather than on someone's memory. It is the pattern that fails an audit when the regulator asks what happened to a verified erasure request, because the data is still sitting there behind a boolean. A verified erasure request hard deletes or irreversibly anonymizes within a stated period, across the primary store, read replicas, search indexes, caches, analytics warehouses, and every processor on the list above, with a stated backup expiry window after which restores no longer carry the record either.
- A record of which third parties receive personal data, and why.
- Breach notification duties understood before there is a breach, including the clock.

**SHOULD**
- Consent captured before non-essential telemetry, with the ability to withdraw.
- Pseudonymize or aggregate wherever the product does not truly need identity.
- Data residency verified against the applicable regime.

**MAY**
- Formal assessment for high-risk processing.
- Certification when contracts require it.

**Acceptance check.** Run a deletion request end to end and confirm the data is gone from the primary store, the analytics tools, and the backup policy.

**Friction.** Rank 1 to 3, depending on consent design.

---

## 13. Payments and third-party integrations

**MUST**
- The amount to charge is decided by the server or by the provider, never accepted from the client. A price submitted by the browser is a discount coupon of arbitrary size.
- Entitlement is granted only after the provider confirms payment, through a signature-verified webhook or a server-side verification call. Never on a client redirect alone, since the client can call the success path directly.
- Webhook endpoints verify the provider signature, reject replays, and are idempotent, because providers retry.
- Card data never touches your servers unless you have deliberately taken on that obligation. Use the provider's hosted fields or checkout.
- Integration credentials are scoped, separated by environment, and rotatable.
- **Delegated access into a third-party system is scoped, enumerable, and revocable.** A service account holding domain-wide delegation or user impersonation gets only the specific API scopes it calls, listed with its owner and reviewed on a schedule; a broad scope granted because narrowing it took an afternoon is a standing key to every mailbox and file in the workspace. Third-party OAuth grants against your workspace or account are inventoried the same way and revoked when an app is retired, replaced, or reported compromised.

**SHOULD**
- Reconciliation between provider records and internal entitlement, so a missed or duplicated event is detected.
- Refund, chargeback, and subscription state changes handled explicitly, since entitlement must follow them.
- Step-up confirmation before changing payout destinations. That is the single most valuable field in the system.
- Mail and collaboration platforms checked for the persistence an attacker leaves behind: forwarding rules, inbox filters that delete or reroute provider notifications, delegated mailbox access, and application-specific passwords. These survive a password reset and a fresh multi-factor enrollment, so clearing them belongs in incident recovery and in the routine review alongside OAuth grants.

**MAY**
- Velocity and anomaly limits on purchase volume per account.
- Separate keys per integration surface.

**Acceptance check.** Submit a modified amount from the client and confirm the server rejects it. Call the post-payment success path directly without paying and confirm no entitlement is granted. Replay a webhook and confirm the effect happens once.

**Friction.** Rank 1, except payout changes, which are rank 3 and worth it.
