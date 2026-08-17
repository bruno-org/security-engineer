# Security Headers

Layer 1 (frontend) and layer 6 (edge) of `references/layer-playbooks.md`. Every header the playbook
names, with the value to send, followed by configuration for a reverse proxy and for a Node
application, the rollout path for the content policy, and what to verify.

Send these from one place. Headers set in two places drift, and the second place usually wins in a
way nobody expects.

---

## The headers

| Header | Value | What it does |
|---|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | The browser refuses plain HTTP to this host for a year, so a hostile network cannot downgrade the first request |
| `Content-Security-Policy` | see the policy below | Limits where scripts, styles, frames, and form posts may come from, which is what turns an injected string into inert text |
| `X-Content-Type-Options` | `nosniff` | Stops the browser from guessing a content type different from the one you declared, which is how an uploaded file becomes a script |
| `X-Frame-Options` | `DENY` | Legacy framing block, for browsers that do not honor `frame-ancestors`. Redundant on current browsers, still one line |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Cross-origin requests carry the origin only, so paths, identifiers, and tokens in query strings stop leaking to third parties |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), payment=(), usb=(), display-capture=()` | Switches off device features the app never uses, including for embedded third-party frames. Empty parentheses mean "no origin, including this one" |
| `Cross-Origin-Opener-Policy` | `same-origin` | Cuts the `window.opener` link to pages you open and pages that open you, which isolates the browsing context |
| `Cross-Origin-Resource-Policy` | `same-origin` | Other sites cannot load your responses as images, scripts, or media |
| `Cache-Control` | `no-store` on every authenticated response | Keeps private responses out of shared caches, out of the back button, and off disk |

**Do not send:** `X-XSS-Protection`. The filter it enabled is removed from current browsers and its
legacy behavior introduced its own leaks. If a framework adds it, remove it or set it to `0`.

**Also suppress the version banners** (layer 11): `server_tokens off` in nginx,
`app.disable('x-powered-by')` in Express. A version number in a response header is a free lookup of
which published vulnerabilities apply to you.

---

## The content policy

Starting policy for an application that serves its own scripts and styles:

```
default-src 'self';
base-uri 'none';
object-src 'none';
frame-ancestors 'none';
form-action 'self';
img-src 'self' data:;
style-src 'self';
script-src 'self';
connect-src 'self';
font-src 'self';
upgrade-insecure-requests
```

Line by line:

- `default-src 'self'` is the fallback for every directive not listed, so anything you forget still
  defaults to same-origin.
- `base-uri 'none'` stops an injected `<base>` tag from repointing every relative URL on the page.
- `object-src 'none'` removes the plugin surface.
- `frame-ancestors 'none'` is the modern clickjacking control. Set it to `'self'` or to specific
  origins if the product is embedded on purpose.
- `form-action 'self'` stops an injected form from posting credentials to another origin.
- `img-src 'self' data:` allows inline data images, which most icon and chart libraries need.
- `upgrade-insecure-requests` rewrites stray `http://` subresources to `https://`.

**Inline scripts.** `script-src 'self'` blocks inline `<script>` blocks and inline event handlers.
Adding `'unsafe-inline'` to `script-src` gives up most of the value of the policy. The two ways out:

1. Move the inline code into a file. Simplest, and it works everywhere.
2. Nonces. Generate a fresh random value per response, send `script-src 'nonce-VALUE'
   'strict-dynamic'`, and put `nonce="VALUE"` on each script tag. `'strict-dynamic'` lets a trusted
   script load further scripts and makes browsers that support it ignore host allowlists, so keep
   `'self'` in the directive as the fallback for browsers that do not.

`style-src 'unsafe-inline'` is the common pragmatic concession, because component libraries write
inline styles. It is a real weakening, and it is far cheaper than the script equivalent. Record the
decision, and keep `script-src` clean.

---

## Reverse proxy (nginx)

```nginx
# In the http block, so the version banner is gone everywhere.
server_tokens off;

server {
    listen 443 ssl;
    server_name example.test;   # PLACEHOLDER: your canonical host

    # PLACEHOLDER: nginx refuses to start with "listen ... ssl" and no
    # certificate, so point these two at your own files before reloading.
    ssl_certificate     /etc/ssl/PLACEHOLDER-fullchain.pem;
    ssl_certificate_key /etc/ssl/PLACEHOLDER-privkey.key;

    # "always" is load bearing. Without it, nginx skips add_header on 4xx and
    # 5xx responses, and error pages are exactly where injected content lands.

    # Ramp this value: 300 first, then 86400, then the 31536000 in the table at
    # the top, and add includeSubDomains only once every subdomain answers over
    # HTTPS. "Safe now, versus observe first" below has the reason.
    add_header Strict-Transport-Security "max-age=300" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), display-capture=()" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;

    # Commented until the login flow is tested against it, because it cuts the
    # window.opener channel that a popup identity flow answers through. Uncomment
    # once that flow is confirmed, per "Safe now, versus observe first" below.
    # add_header Cross-Origin-Opener-Policy "same-origin" always;

    # Keep this on one line. Start with the report-only header name, switch it
    # after the rollout below.
    add_header Content-Security-Policy-Report-Only "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; font-src 'self'; upgrade-insecure-requests; report-uri https://reports.example.test/csp" always;

    location / {
        proxy_pass http://127.0.0.1:3000;
        # TRAP: a single add_header anywhere in this location block discards
        # every add_header inherited from the server block above. If you add one
        # here, repeat all of them here.
    }
}

# Bare domain and any other hostname: redirect to the canonical host over TLS.
server {
    listen 80;
    server_name example.test www.example.test;
    # No Strict-Transport-Security here on purpose. RFC 6797 section 7.2 says a
    # host must not send the header over plain HTTP, and a client must ignore it
    # if it arrives that way. It belongs only on the TLS server block above.
    return 301 https://example.test$request_uri;
}
```

Apache uses `Header always set NAME "value"` inside `<VirtualHost>`; Caddy uses a `header { }` block.
The values are identical.

---

## Node application middleware

No dependency. Register it before the routes, and before any static file handler, so the headers ride
on every response including 404s.

```js
// security-headers.js
const crypto = require('node:crypto');

// PLACEHOLDER: add the third-party origins you actually load, one at a time,
// after the report-only stage tells you which ones exist.
function buildCsp(nonce) {
  return [
    "default-src 'self'",
    "base-uri 'none'",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "form-action 'self'",
    "img-src 'self' data:",
    // Wider than the canonical policy above, which says style-src 'self'. This
    // example assumes a component library that writes inline styles, the
    // concession described under "The content policy". Drop 'unsafe-inline'
    // when the application does not need it, and record the decision when it
    // does.
    "style-src 'self' 'unsafe-inline'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'`,
    "connect-src 'self'",
    "font-src 'self'",
    'upgrade-insecure-requests',
    'report-to csp-endpoint',
    'report-uri https://reports.example.test/csp',
  ].join('; ');
}

function securityHeaders(req, res, next) {
  // Fresh per response. A reused nonce is the same as no nonce.
  const nonce = crypto.randomBytes(16).toString('base64');
  res.locals.cspNonce = nonce; // templates read this: <script nonce="<%= cspNonce %>">

  // Ramp this value: 300 first, then 86400, then the 31536000 in the table at
  // the top, and add includeSubDomains only once every subdomain answers over
  // HTTPS. "Safe now, versus observe first" below has the reason.
  res.setHeader('Strict-Transport-Security', 'max-age=300');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), payment=(), usb=(), display-capture=()'
  );
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');

  // Commented until the login flow is tested against it, because it cuts the
  // window.opener channel that a popup identity flow answers through. Uncomment
  // once that flow is confirmed, per "Safe now, versus observe first" below.
  // res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');

  // Named endpoint for report-to. report-uri is deprecated and still the only
  // one several browsers honor, so send both.
  res.setHeader('Reporting-Endpoints', 'csp-endpoint="https://reports.example.test/csp"');

  // Stage 1: report only. Rename to 'Content-Security-Policy' to enforce.
  res.setHeader('Content-Security-Policy-Report-Only', buildCsp(nonce));

  next();
}

module.exports = { securityHeaders };
```

```js
// app.js
const express = require('express');
const { securityHeaders } = require('./security-headers');

const app = express();
app.disable('x-powered-by'); // removes the framework banner
app.use(securityHeaders);

// Authenticated responses, so a shared cache never holds one:
app.use('/api', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  next();
});
```

`helmet` sets most of the same headers with defaults reviewed by many people. The value of the raw
version above is that every value is visible and greppable. Either is fine; sending nothing is not.

---

## Rolling out the content policy

The policy is the only header here that can break the product, so it gets a rollout instead of a
deploy.

1. **Ship `Content-Security-Policy-Report-Only`** with the target policy and a reporting endpoint.
   Nothing is blocked. Both headers may be sent at once, so an existing enforcing policy keeps
   working while a stricter one is measured.
2. **Collect from real traffic for one to two weeks.** The window has to cover a marketing campaign,
   a payment flow, a support chat session, and whatever the analytics tag manager injects, because
   those are the four that break.
3. **Fix what the reports name.** Move inline scripts to files. Add the third-party origins you
   actually use, one directive at a time. Every addition is a decision about who may run code in
   your users' sessions.
4. **Put a date on the switch** and rename the header to `Content-Security-Policy`. A policy that
   sits in report-only forever protects nothing while everyone believes it does.
5. **Keep the report-only header** for the next tightening, pointed at the stricter policy you want
   next.

Skipping stage 1 breaks analytics, payments, chat, and embeds in the same hour, and the deploy gets
reverted, which leaves no policy at all.

**The reporting endpoint** receives unauthenticated POSTs from any browser and is trivially flooded.
Rate limit it, cap the body size, drop reports whose `document-uri` is not your own host, and never
store the raw report as-is next to application data.

---

## Safe now, versus observe first

**Enable today, on any application:**

- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: DENY` and `frame-ancestors 'none'`, unless the product is embedded on purpose
- `Cross-Origin-Resource-Policy: same-origin`, unless other origins are supposed to load your images,
  fonts, or scripts
- `Permissions-Policy` listing the features you never use
- `Cache-Control: no-store` on authenticated responses
- Version banner suppression

**Observe first:**

- `Content-Security-Policy`. Report-only, always, per the rollout above.
- `Strict-Transport-Security`. Ramp `max-age`: 300, then 86400, then 31536000. `includeSubDomains`
  breaks any subdomain that still answers only over HTTP, so inventory them first. Add `preload` only
  when you are certain about every subdomain forever, because removal from the preload list takes
  months and the browser ignores your header in the meantime.
- `Cross-Origin-Opener-Policy: same-origin`. Breaks identity flows that talk back through
  `window.opener` from a popup. Test the login flow before shipping it.
- `Cross-Origin-Embedder-Policy: require-corp`. Only for pages that need cross-origin isolation. It
  blocks every cross-origin resource that does not opt in, so it breaks third-party images, fonts,
  and frames on contact.

---

## Verify

```sh
# Present and correct on the canonical host
curl -sSI https://example.test/ | grep -iE 'strict-transport|content-security|x-content-type|x-frame|referrer-policy|permissions-policy|cross-origin'

# Present on error responses too, which is where "always" earns its place
curl -sSI https://example.test/this-path-does-not-exist | grep -ic 'x-content-type-options'

# Present on the bare domain, which the nginx block above serves as the canonical host
curl -sSI https://example.test/ | grep -i 'strict-transport'

# And on the alternate hostname, which has to answer under the same rules or it is a bypass
curl -sSI https://www.example.test/ | grep -i 'strict-transport'

# Nothing leaks a version
curl -sSI https://example.test/ | grep -iE '^(server|x-powered-by):'
```

`assets/probe.sh` runs all of the above against a host you name, plus the sensitive path sweep.
