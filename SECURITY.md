# Security Policy

## What this package is

This package has two parts, and they carry different risk.

**Instructions.** The skill file, eight reference documents, and three templates. Markdown that an
agent reads and acts on. Nothing here runs by itself.

**Reference artifacts.** The `assets/` directory ships working code meant to be copied into a
project: a shell script that makes outbound HTTP requests, a SQL file that creates roles and changes
database privileges, a CI workflow that runs containers, and a test file that connects to a
database. Read any of them before you run it, as `assets/README.md` states.

That shapes the risk in two directions. Guidance that is wrong, stale, or unsafe is the primary
concern, because an agent will follow it and a developer will ship it. Code in `assets/` carries the
ordinary risk of code, with the added hazard that a security example is trusted more readily than
other sample code.

## In scope

- **Incorrect or dangerous security guidance.** A weak default, a deprecated algorithm or cipher
  suite, a wrong header value, a Postgres row-level security policy in `assets/rls-multitenant.sql`
  that leaves a tenant boundary open, an SQL or shell example with an injectable pattern.
- **A defect in an `assets/` artifact.** A policy that fails to isolate tenants, a privilege grant
  that is broader than the comment claims, a probe that reports a control as present when it is not,
  a test that passes against a vulnerable system.
- **An acceptance check that passes while the control is broken.** Anything in
  `references/verification.md` or the templates that reports success on a system that is not
  actually protected.
- **An instruction that could push an agent into unsafe behavior.** Touching a live environment,
  running an intrusive scan without authorization, writing a gap register or probe output into a
  public repository, disabling a control to make a test pass, bypassing an authentication challenge
  or a rate limit.
- **Guidance that has aged out.** A provider default that changed, a library or tool recommendation
  with a known CVE, a standard section that has been superseded.
- **Prompt injection material embedded in the text of this repository**, including inside code
  blocks, comments, or example output.

## Out of scope

- Vulnerabilities in an application you built with this skill. Report those to whoever owns that
  system.
- Vulnerabilities in the agent runtime that reads the skill (Claude Code or any other host). Report
  those to that vendor.
- Vulnerabilities in third-party tools named here, such as `semgrep`, `gitleaks`, `trivy`, or
  `osv-scanner`. Report those upstream. Tell us as well if this material uses them in an unsafe way.
- Typos, broken links, formatting, and wording that reads badly. Open a normal public issue for
  those.

## How to report

**[Report a vulnerability privately](https://github.com/bruno-org/security-engineer/security/advisories/new)**

That link opens a private security advisory. It is visible only to you and the maintainer, it needs
a GitHub account and nothing else, and it is the single channel for everything in the in-scope list.

For anything in the out-of-scope list, [open a public
issue](https://github.com/bruno-org/security-engineer/issues/new).

Reporters MUST NOT open a public issue, discussion, or pull request for a suspected problem in the
guidance before it has been discussed privately. A public issue naming the file and the flaw is a
working instruction for everyone who already copied that pattern into production. Public issues are
welcome for everything in the out-of-scope list above.

A report SHOULD include:

- The file and the heading, or the line number.
- What the text currently says.
- The concrete failure it allows: the request, the query, or the sequence that gets through.
- What it should say instead.
- Any source you are relying on: a CVE identifier, a vendor deprecation notice, a specification
  section, or published guidance.

A report MAY include a suggested patch. It is useful and it is not required.

## Response

This project is maintained by one person, so there is no committed response window and no service
level of any kind. Reports are read and triaged by severity: guidance that is actively dangerous is
handled first, and everything else follows as time allows.

You will get a reply. If a report sits without one for longer than seems reasonable to you, send a
reminder through the same channel.

Once a fix is released, you are free to discuss the finding publicly. Ask first if you want to
publish before the fix lands, and we will agree on a date.

## Credit

Reporters are credited by name or handle in the `CHANGELOG.md` entry that carries the fix. Say in
your report how you want to be named, or say that you prefer to stay anonymous. There is no bug
bounty and no payment.
