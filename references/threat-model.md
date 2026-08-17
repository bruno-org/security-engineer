# Threat Model: two tiers, always both

Model the adversary before choosing controls. A control without a named adversary is decoration.

Both tiers are modeled in every engagement, in this order. Tier 0 first, because Tier 0 arrives first.

---

## Tier 0: the automated opportunist

**Who.** Mass scanners, botnets, and off-the-shelf exploit kits. Also the human operator with no deep skill who rents or downloads tooling and points it at whatever is reachable. They do not choose you. They sweep the entire internet continuously and take whatever is easy.

**Volume.** This is the overwhelming majority of hostile traffic any deployed system receives. A new host is being probed within minutes of first responding, long before any human knows it exists.

**Arsenal and behavior.**

- Version scanning against published vulnerabilities in outdated software. This is the single most common entry. Outdated dependency, framework, runtime, operating system, or plugin is the lowest fruit on the tree.
- Automated exploit chains: scan, match a vulnerable version, fire a prepared exploit, no human in the loop.
- Credential stuffing with combinations leaked from other breaches.
- Rented volumetric denial of service. Cheap, requires no skill.
- Opportunistic secret harvesting: bots that continuously scan public repositories and the web for environment files, committed keys, and tokens in logs. Found means used, usually within minutes.
- Common path probing: automatic requests for environment files, version control directories, admin panels, database managers, backup archives, and configuration files that are sometimes there.
- Identifier walking: incrementing or substituting resource identifiers in URLs and API calls to see what comes back.
- Default credential attempts and open registration abuse.
- Defacement of anything with a weak or exposed administrative surface.

**The design implication.** Tier 0 defenses must be **structural**, meaning they hold without anyone remembering to do anything, on every deploy, forever. A control that depends on discipline will eventually be skipped on a Friday. Structural examples: deny-by-default database rules, a build that physically cannot include secrets, a pipeline that publishes an explicit artifact list, a firewall whose default is deny.

**The reframe that matters.** The thing that takes down most small products is not a sophisticated siege. It is the basics: an unpatched dependency, an exposed environment file, an open port, an admin panel with a default password, multi-factor authentication switched off. A system with beautiful layered architecture and one known-vulnerable dependency gets taken by an automated script long before a skilled adversary ever looks at it.

**There is no "too small to be a target."** Being reachable is the only qualification.

### Tier 0 structural checklist for design time

Each item states the design-time answer, not a problem to be discovered later. The list is ordered by yield to the attacker, and items 1 and 2 outweigh the rest by a wide margin: outdated software with a published vulnerability is the single highest-yield entry an automated attacker has, because the exploit code already exists, the scan that finds it costs nothing, and the version is readable from a response banner, a bundle filename, or a lockfile in a public repository. Dependency and runtime freshness is therefore the first thing made structurally true, and items 3 to 14 follow in the order shown. The order sets the sequence of the work, not a cut line: every item on this list is structural before the design is called done. Mass exploitation of a widely deployed package starts within days of the CVE advisory, so items 1 and 2 are the ones that cannot wait for a later pass.

| # | Concern | Structural answer at design time |
|---|---|---|
| 1 | Dependency freshness | Automated update tooling enabled from day one, lockfiles committed, a named owner for the update cadence |
| 2 | Runtime and operating system freshness | Managed runtime, or an image rebuild cadence with pinned base images |
| 3 | Secrets | Never in the client bundle, never in the repository, ignore rules present in the very first commit, push protection on |
| 4 | Admin surfaces | Not on a guessable public path without authentication, protected by strong identity plus multi-factor |
| 5 | Default credentials | No seeded credentials in any environment that can reach the network |
| 6 | Multi-factor authentication | Enforced on every platform that can deploy, read data, or spend money |
| 7 | Repository exposure | Private until reviewed, history scanned before ever going public |
| 8 | Sensitive paths | The deploy artifact contains only what the site needs, so probing finds nothing because nothing is there |
| 9 | Volumetric denial of service | An edge network in front, origin not directly reachable |
| 10 | Rate limits | Present on authentication, on writes, and on anything that costs money per call |
| 11 | Version disclosure | Server and framework banners suppressed, error pages generic |
| 12 | Backups and archives | Never inside the web root |
| 13 | Transport and headers | Encryption enforced, strict transport, content type protections, framing controls |
| 14 | Origin exposure | Origin accepts traffic only from the edge network's address ranges |

---

## Tier 1: the motivated adversary

**Who.** Someone who targets this specific system. Skilled, patient, funded. Reads the code if it is reachable, studies the business, chains small weaknesses into a real breach.

**Capabilities to assume.**

- Full use of modern AI tooling for reverse engineering, exploit development, and automation.
- Professional offensive tooling and infrastructure.
- Purchased breach data: leaked credentials, infostealer logs, database dumps.
- Supply chain interest: a compromised package, a mutable build action, a hijacked content delivery dependency.
- Social engineering against the humans, including the operators and their support providers.
- Support desk account takeover: a call or ticket to a provider's support staff, answering the identity questions with details bought from a breach dump, to get a password reset or a second factor removed on an account the attacker never had.
- Mobile number porting: a port-out request or SIM swap at the carrier that moves the phone number, which defeats SMS and voice-call second factors and any account recovery flow that trusts the number.
- Operates server-side, with no browser. Any defense that only works because a browser enforces it protects nobody here.
- Patience. Weeks to months, not hours.
- Willingness to attack the invoice rather than the service: sustained low-volume traffic that exhausts a paid quota, staying under the threshold that would trigger throttling, until the plan overruns or the service suspends.

**The design implication.** Tier 1 shapes architecture rather than configuration:

- **Least privilege everywhere.** Every key, role, service account, and token gets the narrowest scope and the shortest life that still works.
- **Blast radius limits.** Compromise of one component must not hand over the others. Separate credentials per environment. Separate keys per integration.
- **Defense in depth.** The database enforces access rules even though the API also does. Both, not either.
- **Fail closed on authorization.** When an identity or permission check errors, the answer is deny. Never let an exception in a guard become an allow. Rate limiters are the one place this rule is applied per endpoint rather than globally, because denying everything when the counter store is down converts a cache outage into a full outage: see the failure-mode rule in layer-playbooks.md, layer 2.
- **Detection and recovery.** Assume something eventually succeeds. Can you tell? How fast? Can you revoke, rotate, and restore without losing data?
- **Chained scenarios.** Model at least three realistic multi-step paths for this specific system, for example: a leaked contact address enables targeted phishing, which yields a provider account, which yields data. Write them as sentences, not as abstract categories. The three worked examples below show the required level of detail.

### Worked chained scenarios, to copy as models

Each chain names real records, real credentials, and real steps, and ends with the weakest link. Keep the shape, swap in the specifics of the system under review.

- **Chain A. Public record to full domain control.** The `rua=mailto:` address published in the domain's DMARC record names the administrator, so the attacker knows exactly who to phish and sends one message to that person with a registrar-branded login page. The captured registrar password gives control of DNS, so the attacker adds an MX record that copies inbound mail and answers an ACME DNS-01 challenge to issue a valid certificate for the apex and every subdomain. With mail interception and a trusted certificate in hand, every password reset and every account recovery flow at every connected provider now resolves to the attacker. **Weakest link: the registrar account holds one password and no phishing-resistant second factor, so a WebAuthn security key plus registrar transfer lock breaks the chain at step two, before DNS ever moves.**

- **Chain B. Moving tag in CI to production secrets.** A build workflow references a third-party action as `uses: some-org/setup-tool@v3`, a tag its maintainer can repoint at any commit. The maintainer's account is taken over, the tag is moved to a commit that reads the runner environment, and the step runs inside the job that already holds the deploy credential. It enumerates the environment, decrypts what the job is entitled to decrypt, and posts the production database URL and the service-role key to an external host. The application repository was never touched, so a code review of the application finds nothing at all. **Weakest link: the mutable tag, so pinning every third-party action to a full 40-character commit SHA and scoping the deploy credential to one environment through short-lived OIDC tokens breaks the chain at the first step.**

- **Chain C. Preview deployment to production data.** A pull request preview build is published at a generated hostname with no authentication in front of it, and it reads the production database because the preview environment inherits the production connection string. The hostname becomes public the moment its certificate is issued, so the attacker finds it by watching Certificate Transparency logs for the organization's domain. That preview runs a build from before the authorization fix, so its access rules still permit a read that production now denies, and the rows it returns are real customer records. **Weakest link: the shared connection string, so giving previews their own database with seeded data, and enforcing access control in the database itself with row-level security that an old build cannot bypass, breaks the chain even while the stale deployment stays reachable.**

---

## How the two tiers interact

Tier 1 sits on top of Tier 0, never in place of it. A system hardened only against the sophisticated adversary while leaving an outdated dependency exposed is the classic failure: it dies to the automated attack it never modeled.

Order of work is fixed:

1. Make every Tier 0 item structurally true.
2. Then design for Tier 1: privilege, isolation, blast radius, detection, recovery.
3. Then, and only then, consider exotic threats.

---

## Adjusting the model

The user may name a different primary adversary: a competitor, a hostile insider, a curious user, a regulator. Adjust Tier 1 to fit, and explain what changed. Tier 0 never changes and is never removed, whatever the user asks for, because Tier 0 does not care who the user thinks their enemy is.

**Insider variant.** When the named adversary is an insider, the emphasis moves to: least privilege on humans, audit logging that the actor cannot erase, separation of duties on money and data export, and revocation speed on departure.
