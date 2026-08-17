# Stack Profiles

The layers never change. What changes is who is responsible for each one, and which failure modes are live. Identify the profile in Step 1, then apply the deltas below on top of the layer playbooks.

Most real systems are a blend. Apply every profile that is present.

---

## Profile A: managed and serverless

Static or server-rendered frontend on a managed host, functions at the edge or on demand, a managed database, managed identity, managed storage.

**The platform handles:** operating system patching, network isolation of the host, transport encryption, volumetric absorption at the edge, physical security, and usually backups.

**You still own, and this is where these systems fail:**

- **Data rules.** The single biggest risk in this profile. The client typically holds a public key and speaks to the data platform directly, so the platform's access rules are the entire perimeter. Rules off means full export.
- **Direct database exposure.** Managed Postgres and equivalent services usually accept connections from any address on the database port (5432, and commonly 6543 for the pooler), authenticated by the database password alone. That password connects as a role that bypasses row-level security entirely, so every rule written for the client path is irrelevant on that connection. Keep it in a secret store, never in a variable the client bundle can read, and turn on the network restriction or address allow list where the plan offers one.
- **Defaults left open.** Managed platforms enable modules you never asked for. Public sign-up on the identity module of a product with no registration becomes a free mail relay that burns your sending domain. Public storage buckets. Real-time subscriptions open to anonymous callers. Anonymous access modes. Audit every module, including the ones the product does not use.
- **Credential lifetime.** Platform-issued client keys often carry lifetimes measured in years. Treat that as a decision, not a default. Know how to rotate before you need to.
- **Preview and branch deployments.** Automatically published, publicly reachable, frequently pointing at production data, and outside every rule written for the canonical hostname. Protect or disable them.
- **The deploy artifact.** Publishing the working directory ships tests, configuration, lockfiles, and internal documentation to the public web. Publish an explicit list.
- **Function-level authorization.** Every function is a public endpoint. There is no private network in front of it. Each one verifies identity itself.
- **Cost as an attack surface.** Per-invocation and per-row pricing turns a flood into an invoice. Spend caps, quotas, and alerts before launch.
- **Cold-path secrets.** Environment variables exposed to the client bundle by a naming convention are the most common secret leak in this profile.

**Not applicable, and say so explicitly:** kernel tuning, host firewall rules, container hardening, unattended upgrades.

---

## Profile B: self-hosted server or container

A virtual machine, a dedicated server, or containers you operate, usually behind a reverse proxy.

**You own everything in Profile A, plus the machine.** This is the profile most often left half-covered, because teams secure the application and forget the host.

- **Provisioning order is defensive:** firewall, then runtime, then proxy, then the application. Publishing the application first creates a window that automated scanners find within minutes.
- **Default-deny inbound.** Only the ports the product needs. Administrative access restricted to known addresses. Databases, caches, and internal dashboards never exposed to the public internet, which is a mistake made constantly with container port publishing.
- **The origin address is the crown jewel.** If the real address of the machine has ever been public, through a historical record, a certificate log, a mail header, a screenshot, or a monitoring service, treat it as burned. Provision a new address and, more importantly, restrict the origin firewall to the edge network's address ranges. Without that second step, rediscovery is a matter of time and the edge protection is decorative.
- **Unattended feature upgrades on critical infrastructure are a hazard in production.** An automatic update of a reverse proxy can install a broken version by itself and take the service down without anyone touching anything. Pin the version, ideally by immutable digest, test the upgrade elsewhere, then apply it in a controlled window with rollback ready. Operating system security patches are the opposite case: leave that channel applying on its own, because an unpatched known vulnerability is the most common way systems are taken. Only feature and major-version upgrades are pinned and moved deliberately, as in layer-playbooks.md, layer 5.
- **Containers:** run unprivileged, drop capabilities, disable privilege escalation, keep the filesystem read-only where possible, never mount the host control socket, never bake secrets into images or pass them as build arguments, pin base images by digest, scan them.
- **Kernel and limits:** enable protections against connection floods, raise connection backlogs and file descriptor limits from their conservative defaults. A service that refuses connections at a low limit falls over without any real flood.
- **Remote access:** keys only, no password authentication, no direct root login, brute-force protection active, and administrative ports restricted by address.
- **Monitoring:** alert on proxy processor load, established connection counts, and half-open connections. Without these, the first sign of an attack is the outage.
- **Integrity:** the process serving files should not be able to rewrite them. Deploy immutably, and monitor the served directory for change.
- **Backups:** automated, off-host, and restore-tested. This is the recovery path for both a hardware failure and a ransom event.

---

## Profile C: document databases and backend-as-a-service without a server

Products where the mobile or web client talks straight to a cloud database, with no server of your own in the middle.

- **The security rules are the entire application security.** There is no server-side gate. Every rule must be deny by default and owner-scoped, and every rule must be tested like production code, because a mistake in a rule is a full breach.
- **Test-mode rules are a countdown.** Open rules generated for prototyping expire, and teams either extend them or never notice they are open. Never launch on them.
- **Validation lives in the rules.** Type, size, and shape must be enforced there, since no server exists to validate.
- **Aggregation and cost.** Unbounded queries from clients are both a data exposure and a billing risk. Constrain what a client can request.
- **Client-side functions and callable endpoints** are public entry points and verify identity independently.
- **Storage rules are separate from database rules** and are frequently left open after the database rules are fixed.

---

## Profile D: mobile and desktop clients

- **Anything shipped in the binary is public.** Assume every key, endpoint, and constant is extracted. Certificate pinning and obfuscation raise cost, they do not create secrecy.
- **The server treats the client as hostile,** because a modified client is trivial to build. All authorization, pricing, and validation are server-side.
- **Local storage of credentials** uses the platform keystore, never plain files or preferences.
- **Update path.** Ship a way to force upgrade off a vulnerable version, or a vulnerability lives as long as the oldest installed build.
- **Permissions requested from the operating system** are minimized, because each one is both a privacy liability and an attack surface.
- **Deep links and inter-process entry points** are input, validated like any other.

---

## Profile E: local-only tools

No network exposure by design: scripts, desktop utilities, offline processing.

Security still applies, at a smaller radius. The relevant layers:

- **Secrets and credentials** the tool holds for other services. A local tool with a cloud token is a cloud credential sitting on a laptop. Use the platform keystore, scope the token, and let it expire.
- **The workstation joins the production attack surface.** A local tool holding a cloud token puts the developer machine inside that surface, so the token gets the same treatment as any production credential: scoped to one project and the operations the tool actually calls, an expiry measured in hours or days, and a revocation path in the provider console that works without access to the machine.
- **Dependencies.** The dominant risk in this profile. A malicious package in a local tool runs with the full privileges of the person who ran it, with access to their files, keys, and network. Pin, scan, review anything that executes on install.
- **Input handling.** Files the tool parses are input, whether they arrived by email, download, or share. Path traversal on extraction, archive expansion, and deserialization of untrusted data are the live vectors.
- **File permissions.** Do not write world-readable files containing sensitive output.
- **Command construction.** Never build a shell command by concatenating values from a file or an argument.
- **Update path.** A local tool with no update mechanism keeps its vulnerabilities forever.
- **Data at rest.** If the tool stores personal data locally, that store is subject to the same privacy duties as a server.

**Not applicable, and say so explicitly:** edge, transport, denial of service, most of the infrastructure layer. Record them as Not applicable with the reason, rather than leaving them blank.

---

## Profile F: internal tools and administrative panels

Reachable only by staff, in theory.

- **Internal is not a control.** Internal tools end up exposed through a shared link, a misconfigured proxy, a bookmark, or an employee's compromised session. Authenticate and authorize them like public systems.
- **They concentrate privilege,** which makes them the highest-value target in the system. Multi-factor is mandatory, and destructive actions deserve step-up confirmation.
- **Audit logging matters more here than anywhere else,** because the actor is trusted and the damage is broad. Log the actor, the target, and the outcome, including denied attempts, and store it where the actor cannot erase it.
- **Data export is the crown jewel action.** Limit it, log it, and alert on unusual volume.
- **Impersonation features,** if present, are logged, consented where required, and never silent.

---

## Choosing controls when profiles blend

When a system spans profiles, the strictest applicable rule wins. A serverless frontend with one self-hosted worker inherits the entire self-hosted infrastructure playbook for that worker, not a reduced version of it. State which controls belong to which component, so nobody assumes the managed platform covers the machine.

Draw the boundary per request path. One table sits on several paths at once, and each path has its own threat properties. Take a system with a server-rendered app on a managed host, a managed Postgres behind it, a browser that also queries the data platform directly with the public anon key, and an internal admin area. The `orders` table is reached three ways:

- **Server path.** Route handlers on the managed host, holding the service key, running a tenant check in code before they query.
- **Direct path.** The browser, holding the anon key, calling the platform's REST endpoint (`/rest/v1/orders`) and its realtime channel with no code of yours in between at request time.
- **Admin path.** A staff session reading and exporting across every tenant.

Row-level security on `orders` is the only control standing between the anon key and the rows, so on the direct path it carries the full weight, regardless of how careful the server path is. A tenant check that lives only in a route handler covers one path of three and leaves the direct traffic untouched. The admin path adds Profile F duties to the same rows: audit logging of actor, target and outcome, export limits, step-up confirmation on destructive actions.

**The general rule:** for each data object, enumerate every path that can reach it. Then confirm the strictest control sits where all the paths converge, which is the data store itself. Controls in server code sit above that point and add to it.
