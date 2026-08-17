# Assets

Copyable implementations of controls the playbooks prescribe. Each file covers one layer of
`references/layer-playbooks.md` and names the exact header, algorithm, constraint, or command
involved.

| File | Layer | What it implements |
|---|---|---|
| `rls-multitenant.sql` | 3, data store | Tenant isolation in PostgreSQL: row level security enabled and forced, a `SECURITY DEFINER` membership helper with a pinned search path, one policy per command with both halves, column-level privilege revocation, and the composite foreign key that makes a cross-tenant reference impossible |
| `security-headers.md` | 1, frontend and 6, edge | The header values to send, nginx and Node configuration, the report-only rollout path for `Content-Security-Policy`, and which headers are safe to enable today |
| `ci-security.yml` | 8, CI/CD, 9, secrets, and 10, dependencies | A GitHub Actions workflow: secret scanning over full history, dependency audit that fails on high severity, static analysis, third-party actions pinned by commit SHA, least-privilege `permissions` |
| `probe.sh` | verification, live probes | External pre-launch probe against a host you name: transport, security headers, version banners, sensitive paths compared against a nonexistent-path baseline, cache exposure |
| `tenancy.test.example.ts` | verification, automated tests | The cross-tenant denial suite against real access rules with an unprivileged client: cross-tenant read, cross-tenant write, privileged column, cross-tenant foreign key, and not-found versus not-yours |

---

## Before you use any of them

**These are starting points to adapt.** Running a file here does not make a system secure. Each one
implements a specific mechanism correctly; whether that mechanism is the right one for your data
class, your profile, and your threat model is the decision the rest of the package exists to make.

**Read every line before running it.** Two of these files change database privileges and one changes
what your pipeline blocks on. Both categories break a working deployment when applied without
reading.

**Replace every placeholder.** The files fail loudly rather than quietly where that was possible, and
the values to change are:

| File | Change |
|---|---|
| `rls-multitenant.sql` | Schema name `app`, role names `app_client` and `app_anon`, the identity source inside `app.current_user_id()`, and every table and column name |
| `security-headers.md` | The host `example.test`, the reporting endpoint `https://reports.example.test/csp`, the proxy upstream `127.0.0.1:3000`, and the third-party origins your policy needs |
| `ci-security.yml` | Every action pin (40 zeros) and every image digest (64 zeros), plus the Node version. The header of that file carries the commands that resolve a tag to a SHA |
| `probe.sh` | Nothing in the file. Pass the hostnames as arguments |
| `tenancy.test.example.ts` | The two connection strings in the `PROJECT SETUP` block, and the fixture identifiers if your schema differs |

**Two of them are only meaningful under the right identity.** `rls-multitenant.sql` and
`tenancy.test.example.ts` prove nothing when run as a superuser or as a role holding `BYPASSRLS`,
because both ignore every policy. The test file carries a guard test for this; the SQL file says so
at the top of its test block.

**`probe.sh` touches systems.** Read-only requests, 15 to 17 of them depending on which optional
hostnames you pass, no authentication, no fuzzing. Point it only at hosts you operate or hold
written permission to test.

---

## What is deliberately absent

These five cover the layers where a copyable artifact does the whole job. The rest of the package
covers what configuration cannot: backups with a tested restore, multi-factor on administrative
accounts, secret storage and rotation, deletion and export paths, alerting on denied authorization,
and upload validation by real content. A system passing everything in this directory can still fail
all six.
