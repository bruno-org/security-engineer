# The Five Defaults

The failure classes that dominate real breakage in quickly built applications, and especially in code produced with AI assistance. They are not exotic. They are what actually gets exploited.

Check all five on every feature that touches data, identity, money, files, or the network. The check takes three minutes.

Examples use pseudocode that reads like a typical web stack. Translate to the project's actual stack, and to its actual naming.

---

## Default 1: data rules deny by default

**The question.** If the application layer were bypassed entirely, and the caller spoke to the data store directly with the public client credential, what could they read or write?

**Why it dominates.** Managed platforms ship access rules off, or in an open test mode meant for prototyping. Teams build the whole product with rules off, launch, and never turn them on. The public client key is visible in the browser to every user, so with rules off, the key is a full database export.

**Insecure**

```
# Table created, rules never enabled.
create table patients (id, clinic_id, name, phone);
# Client holds the public key. It can select every row of every clinic.
```

**Secure**

```
create table patients (id, clinic_id, name, phone);
enable row security on patients;
force row security on patients;   # without this the table owner bypasses its own
                                  # policies, and the migration role is usually the owner

# Deny by default, then grant narrowly, scoped to the caller's tenant.
policy patients_read  on patients for select using  ( is_member(clinic_id) );
policy patients_write on patients for all    using  ( is_member(clinic_id) )
                                             with check ( is_member(clinic_id) );
```

**The half-done version that still leaks.** Writing the read condition and forgetting the write condition. The read rule stops the caller reading other tenants' rows. Only the write condition stops them inserting rows *into* another tenant. Both are required.

**Also required**
- Rules enabled at table creation, not before launch. A table created later without rules is the hole.
- Columns that must never be client-writable are revoked at the privilege level, not merely omitted from the interface. Subscription state, plan, role, credit balance, and verification flags belong to the server.
- Migrations reviewed for rules, because a migration is the usual way a rule silently disappears.
- The same discipline applies to document databases and storage buckets, which have the identical failure mode under different names.

**Acceptance check.** With only the public client credential, attempt to read and to write a record belonging to another tenant. Both denied. Re-run after every migration.

---

## Default 2: authorization lives on the server

**The question.** If the client lies about who it is, what it may do, or what something costs, does the server catch the lie?

**Why it dominates.** It is fast to build the permission check where the data already is, in the browser. Anything the browser holds, the user edits.

**Insecure**

```
# Client
if (localStorage.getItem('role') === 'admin') { showAdminPanel() }

# Server
function deleteUser(req) {
  if (req.body.isAdmin) { db.deleteUser(req.body.targetId) }   # trusts the caller
}
```

The user edits one storage value and gains the panel. The user posts one extra field and gains the deletion.

**Secure**

```
# Server
function deleteUser(req) {
  const actor = verifySession(req)               # identity from the verified session
  const role  = db.getRole(actor.id)             # role from the server's own store
  if (role !== 'admin') return deny()
  db.deleteUser(req.body.targetId)
}
```

**The rule.** Hiding a control in the interface is user experience. It is never a security control. Assume every hidden route is called directly, because it is.

**Extends to**
- Prices, discounts, quantities, and totals. Never accept an amount from the client. Look it up server-side, or let the payment provider compute it.
- Entitlements and plan gates. Read from the server's own record of the subscription.
- Any identifier of "who I am". Derived from the session, never from the payload.
- Claims inside tokens the client can mint or edit. Verify signature and source, and prefer reading authorization from your own store.

**Acceptance check.** Call every privileged route with a normal user's valid session, and with every client-visible role representation flipped to administrator. All denied.

---

## Default 3: ownership is checked per object

**The question.** If the caller swaps an identifier for one belonging to someone else, do they get that object?

**Why it dominates.** The query is written to fetch by identifier, because that is the natural way to write it. The owner condition is the part that gets forgotten. This is the most common serious flaw in web APIs, and it is trivially automatable: an attacker walks identifiers in a loop.

**Insecure**

```
GET /api/invoices/:id
function getInvoice(req) {
  const user = verifySession(req)             # authenticated, so it feels safe
  return db.invoices.findById(req.params.id)  # any authenticated user reads any invoice
}
```

Authentication is present. Authorization is absent. Being logged in is not permission to read a specific object.

**Secure**

```
function getInvoice(req) {
  const user = verifySession(req)
  const invoice = db.invoices.findOne({
    id: req.params.id,
    ownerId: user.id            # ownership is part of the query, not an afterthought
  })
  if (!invoice) return notFound()
  return invoice
}
```

**Patterns that make this structural rather than remembered**
- Scope every query by owner or tenant at the data access layer, so an unscoped query is the exception that stands out in review.
- Let deny-by-default data rules answer it too, so a forgotten condition returns nothing instead of returning someone else's record. Defense in depth: application scoping and database rules, both.
- Return the same response for "does not exist" and "not yours". Different responses are an enumeration oracle that maps your data for the attacker.
- Prefer unguessable identifiers over sequential integers. This is hardening, not a control. It slows the walk, it does not stop it. Never treat an unguessable identifier as authorization.
- Watch every place an identifier arrives: path, query string, body, header, batch arrays, nested references, and identifiers embedded in webhooks or exports.

**The trap that catches careful people.** Cross-object references. A row correctly scoped to your tenant that points at a *related* record belonging to someone else. If an appointment belongs to your clinic but references a professional, a patient, or a document from another clinic, the ownership check on the parent row passes and the child leaks. Enforce the relationship in the schema itself, with a composite foreign key that includes the tenant, so the database refuses the cross-tenant reference physically. Verify this for every foreign key that crosses a tenant boundary, including the ones your own design just introduced.

**Acceptance check.** For each object type, authenticate as user A, then request, update, and delete an object belonging to user B by identifier. All denied, all with an indistinguishable response. Then check every foreign key for cross-tenant references.

---

## Default 4: secrets never reach the client or the repository

**The question.** Where does this credential live, who can read it, and what happens the day it leaks?

**Why it dominates.** Framework conventions make it easy to expose a variable to the browser bundle by naming it with the wrong prefix. Bots continuously scan public repositories and published bundles for credential shapes, and act within minutes of finding one.

**Insecure**

```
PUBLIC_PRIVILEGED_KEY=...     # prefix publishes it into the browser bundle
# or committed .env
# or passed as a container build argument, persisting in the image layers
```

**Secure**

```
# Server-side only, never prefixed for client exposure.
PRIVILEGED_KEY=...            # provided by the platform secret store at runtime

# Import guards so a client component cannot pull in the privileged client at all,
# failing the build rather than shipping the key.
```

**Rules**
- Ignore rules exist in the first commit, before a secret could enter.
- Privileged credentials are used only in server code paths, and the build fails if a client path imports them.
- Public identifiers meant to be public are documented as public, so nobody mistakes one for a secret or a secret for one. A public client key is only safe because the data rules of Default 1 are doing their job.
- A credential that was ever committed, pasted, or shown on screen is compromised: rotate first, then clean history. Cleaning without rotating protects nothing.
- Separate credentials per environment, each with the narrowest scope that works.

**Acceptance check.** Scan the entire history with a secret scanner. Search the built client bundle for credential shapes. Confirm only intended public identifiers appear.

---

## Default 5: all input is hostile

**The question.** What happens when this field, file, or payload is malicious, enormous, or the wrong type?

**Why it dominates.** Validation gets written in the form, where the developer is looking. The form is not where requests come from.

**Insecure**

```
# Client validates, server trusts.
function createPost(req) { db.posts.insert({ body: req.body.text }) }
render(`<div>${post.body}</div>`)             # stored script executes for every reader
```

**Secure**

```
const schema = { text: string().max(5000), tags: array(string()).max(10) }

function createPost(req) {
  const input = schema.parse(req.body)        # validate on the server, always
  db.posts.insert({ body: input.text })       # parameterized, never concatenated
}
render(escapeAsText(post.body))               # encode on output, by default
```

**Server-side validation covers** type, size, range, format, allowed values, and array length. Client-side validation is a courtesy to honest users, never a control.

**Uploads deserve their own list, because they are the most commonly mishandled input**
- Validate the real type by inspecting file content, not by trusting the extension or the client-declared content type. Both are attacker-controlled.
- Enforce a size limit before reading the whole file into memory.
- Generate a new stored name. Never use the client's filename in a path, which is how traversal happens.
- Store outside the web root, or in object storage with the bucket set to private and access granted through short-lived signed links.
- Serve with a content type that cannot execute, and force download for anything not meant to render. Vector images and markup files can carry script and become stored cross-site scripting when served from your origin.
- Strip image metadata, which routinely carries location and device details.
- Scan for malware when files are shared between users.

**Also input, and frequently forgotten:** query parameters, headers, cookies, webhook payloads, imported files, third-party API responses, and anything read from a queue. Data crossing a trust boundary is input, whatever it is called.

**Acceptance check.** Submit a scripted payload through every user-content path and confirm it renders as text. Upload a file whose extension lies about its content and confirm rejection. Submit an oversized payload and confirm rejection before processing.

---

## The sixth question, for anything with a cost or a queue

**What stops this from being called a million times?**

Cost-based denial of service is the easiest attack on a small product with a metered backend. The attacker does not need to break anything. They need your invoice to grow faster than your revenue, or your quota to run out mid-launch. Sustained low-volume calls stay under naive thresholds and still exhaust a monthly plan.

**Required for any endpoint that costs money, sends mail, generates media, calls a paid model, or writes to a queue**
- Rate limits per address and per account, with the failure mode decided and written down per endpoint: deny when the limiter cannot decide on credential checks, payments, invitations, and anything billed per call; elsewhere degrade to an in-process limiter and alert, so a cache outage does not become a full outage.
- Spend caps and usage alerts at the provider, set before launch, not after the first surprise bill.
- Quotas per account for anything expensive.
- Queue and job limits, so one caller cannot fill the worker pool.
- Public registration and mail-sending paths closed if the product does not need them, since an open sign-up on an unused identity module becomes a free relay for someone else's spam and burns your sending reputation.

**Acceptance check.** Call the expensive endpoint in a short burst and confirm the limiter engages. Confirm the spend cap and alert exist at the provider, with a real destination.
