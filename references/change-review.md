# Reviewing one change

For Mode C, when the subject is a diff: a pull request, a branch, a commit
range, or the code that was just written in this session. The full layer walk
does not run here. Running it is a failure, not thoroughness.

Three obligations survive from the full process: the Five Defaults for what this
change touches, an acceptance check for anything called required, and the review
of your own generated code. Everything else is optional and usually noise.

---

## 1. What a diff hides

A diff is a poor witness. It shows what moved, not what the code now permits.

- **Deletion reads as a clean line.** A removed ownership condition, a removed
  guard, a removed signature check: all of them appear as a shorter, tidier
  function. Read every removal as a question, not as cleanup.
- **The dangerous part is often outside the diff.** A new endpoint is added and
  the table it reads has no policy, in a migration written last month. A new
  column joins a table whose access rules were written before it existed. Follow
  the change to the surfaces it reaches, and read those even though they are
  unchanged.
- **The hunk is not the file.** Three lines of context does not show that the
  handler above derives identity from the request body. Read the whole function,
  and the whole file when it is small.
- **A safe change can expose an unsafe surface.** Making a route public, adding
  a field to a response, widening a query: the change itself is correct and the
  consequence is a leak.

Get the real diff first. `git diff BASE...HEAD` against the merge base, not
against whatever happens to be checked out.

---

## 2. Route by what the change touches

Walk only the layers this change reaches. Name them explicitly, and do not list
the others as not applicable: leave them out.

| The change touches | Read these | Ask first |
|---|---|---|
| A new table, collection, or bucket | 3 data store | Were the rules enabled at creation, in the same migration? |
| A query or a handler | 2 backend, 3 data store | Is the owner condition present, and does it come from the session? |
| Roles, sessions, tokens, sign-up | 4 identity | Can the client influence its own privilege, anywhere in this path? |
| Money, plans, entitlements, webhooks | 13 payments | Does the amount or the entitlement originate anywhere other than the provider or the server? |
| File upload or download | 2 backend, 3 data store | Is the type decided by content rather than by the name the client sent? |
| A new dependency | 10 dependencies | Does it run code on install, and who maintains it? |
| Pipeline, workflow, or deploy configuration | 8 CI/CD, 9 secrets | Does untrusted input reach a job that holds credentials or write permission? |
| Environment variables or configuration | 9 secrets | Does anything private cross into a client-visible name? |
| A public route, a header, an error path | 11 public exposure, 7 observability | Does the response carry internals, versions, or personal data? |
| A prompt, a tool, or a model call | 14 AI surface | Does untrusted content reach a tool that can act or send? |

If the change touches none of these, say so in one line and stop. Most changes
are not security changes, and saying that plainly is part of the job.

---

## 3. Findings discipline

**The report is judged on precision, not volume.** A review that lists twelve
theoretical issues to be thorough teaches the team to skim the next one, and the
real finding dies inside it. Every finding must survive all five questions
before it is written down:

1. **Is it real in this code?** Point at the line. Not the pattern, the line.
2. **Can input an attacker controls reach it?** Trace the path from a request,
   an upload, a webhook, a crawled page, or a model output. No path, no finding.
3. **Does something upstream already stop it?** A framework escape, a policy on
   the table, a gateway rule, a type at the boundary. Check before reporting, and
   if it does stop it, the finding is gone rather than downgraded.
4. **Can you state the consequence in one concrete sentence?** Who gets what.
   "Any logged-in customer can read every other customer's invoices by changing
   the number in the URL" is a finding. "Improper access control" is a label.
5. **Is it in this change, or was it already there?** Both are worth saying, and
   they are different sentences. Never let pre-existing debt block a merge
   silently, and never let it pass unmentioned either.

**Do not report:**

- Hardening with no threat attached, phrased as "consider adding".
- Findings in test fixtures, seeds, examples, and generated files, unless the
  fixture ships to production or holds a real credential.
- Theoretical weakness in a library, with no path from this code.
- Style, structure, naming, and performance. Not this review.
- The same defect once per occurrence. Report the class once, list where.

**Rank what remains** by consequence and reachability, not by scanner severity.
The one that ends the review is the one that gets fixed.

---

## 4. The merge gate

The deliverable is not a list. It is the answer to what must be true before this
merges, in three parts:

- **Blocking.** The exploitable ones. Each with the exact change, and the check
  that proves it is closed.
- **Follow-up.** Real but not blocking. Each with an owner, otherwise it is a
  wish.
- **Noted.** Pre-existing, out of scope for this change, recorded so the next
  reader does not rediscover it.

When there is nothing blocking, say that in the first line. A review that never
approves anything is not being careful, it is being useless slowly.

---

## 5. Fix, then prove it again

When the fix is applied, re-run the check that failed and show the result. Not
the whole suite, the specific one.

A fix that was never re-verified is a claim. This matters most where the fix is
a configuration rather than code: a policy enabled in a dashboard, a permission
narrowed in a pipeline, a setting changed in a provider console. Read the value
back after changing it, because a save that appears to succeed can be rejected
by a plan limit or applied to a different environment than the one on screen.

Where the fix closes a defect that a test could have caught, write that test
before closing the item, and watch it fail against the unfixed code first. See
the negative control in `references/verification.md`.
