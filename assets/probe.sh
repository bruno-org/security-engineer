#!/bin/sh
# ============================================================================
# probe.sh - the external pre-launch probes from references/verification.md.
#
# What it does: fetches the canonical host, a second hostname (the bare domain
# by default, or one you name), an optional platform preview host, and a short
# list of sensitive paths, then reports on transport, security headers, version
# banners, and cache exposure.
#
# Safety, by design:
#   - read-only GET requests only, no writes, no POSTs
#   - a fixed count, 15 to 17 requests total depending on which optional
#     hostnames are given, no fuzzing, no wordlists
#   - no credentials sent, no authentication attempted, no login guessed
#   - it creates nothing, so there is nothing to clean up afterwards
# Run it only against hosts you operate, or hosts you hold written permission
# to test. Probing enough to prove a control is verification. Probing more than
# that is an attack on your own product.
#
# Requires: curl, and a POSIX shell.
# ============================================================================

set -u

UA='security-engineer-probe/1.0'
TIMEOUT=10
FINDINGS=0
INCONCLUSIVE=0
REQUESTS=0
CODE=''
SIZE=''
CURL_EXIT=0
SUCCESS_HEADERS=''

# The headers the nginx "always" flag in assets/security-headers.md exists for.
# They are tracked as a set so the same list can be compared between a success
# response and an error response.
ALWAYS_HEADERS='strict-transport-security content-security-policy
x-content-type-options x-frame-options referrer-policy permissions-policy
cross-origin-opener-policy cross-origin-resource-policy'

usage() {
  cat <<'EOF'
Usage: probe.sh HOST [PREVIEW_HOST] [ALT_HOST]

  HOST          the canonical hostname, for example www.example.test
  PREVIEW_HOST  optional platform preview hostname, for example
                my-project-abc123.vercel.app. Pass '' to skip it and still
                name ALT_HOST.
  ALT_HOST      optional second hostname to check under the same rules, for
                example the apex when HOST is the www name, or the www name
                when HOST is the apex. Without it, the second hostname is the
                bare domain, and only when HOST starts with "www.".

Probes HOST, the second hostname, PREVIEW_HOST if given, and the sensitive
paths on HOST.

Exit codes:
  0  no findings, and every check reached the host it was aimed at
  1  at least one finding is printed
  2  usage error, so nothing was probed
  3  no findings, but at least one check never reached its target. The result
     is inconclusive, not a pass: fix the network or the name and re-run.

Examples:
  ./probe.sh example.test
  ./probe.sh www.example.test my-project-abc123.pages.dev
  ./probe.sh example.test '' www.example.test
EOF
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

HOST=$1
PREVIEW=${2:-}
ALT=${3:-}

case "$HOST$PREVIEW$ALT" in
  *http://*|*https://*)
    echo "Pass hostnames, not URLs." >&2
    exit 2
    ;;
esac

case "$HOST" in
  www.*) BARE=${HOST#www.} ;;
  *)     BARE=$HOST ;;
esac

# A hostname given on the command line wins over the one derived from a "www."
# prefix, so an apex-only canonical host can still have its www name checked.
if [ -n "$ALT" ]; then
  SECOND=$ALT
  SECOND_LABEL='second hostname'
else
  SECOND=$BARE
  SECOND_LABEL='bare domain'
fi

TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT INT TERM

note()    { printf '  %s\n' "$*"; }
warn()    { printf '  WARN:    %s\n' "$*"; }
finding() { printf '  FINDING: %s\n' "$*"; FINDINGS=$((FINDINGS + 1)); }
# A check that never reached its target proves nothing in either direction, so
# it gets its own counter instead of being read as a control that passed.
unknown() { printf '  UNKNOWN: %s\n' "$*"; INCONCLUSIVE=$((INCONCLUSIVE + 1)); }

# fetch URL -> sets CODE and SIZE, writes response headers to $TMP.
# CURL_EXIT keeps curl's exit status, because a name that does not resolve and a
# request that timed out are different answers and callers have to tell them
# apart.
fetch() {
  REQUESTS=$((REQUESTS + 1))
  _out=$(curl -sS -m "$TIMEOUT" -A "$UA" -D "$TMP" -o /dev/null \
         -w '%{http_code} %{size_download}' "$1" 2>/dev/null)
  CURL_EXIT=$?
  [ "$CURL_EXIT" -eq 0 ] || return 1
  CODE=${_out%% *}
  SIZE=${_out##* }
  return 0
}

# curl exit 6 is "could not resolve host" and 7 is "could not connect". Both
# mean the host is not reachable at all, which is the answer a host that should
# not answer is supposed to give. Every other status means the probe itself did
# not complete.
curl_exit_is_refusal() {
  case "$1" in
    6|7) return 0 ;;
    *)   return 1 ;;
  esac
}

# hdr NAME -> the value of that response header from the last fetch, or empty.
# Header names are case-insensitive, so the match is too.
hdr() {
  tr -d '\r' < "$TMP" | grep -i "^$1:" | tail -n 1 | cut -d: -f2- | sed 's/^[[:space:]]*//'
}

# present_headers -> the names from ALWAYS_HEADERS that the last fetch carried,
# separated by single spaces, or empty. Reads $TMP only, so it sends no request
# of its own.
present_headers() {
  _found=''
  for _n in $ALWAYS_HEADERS; do
    if [ -n "$(hdr "$_n")" ]; then
      _found="$_found $_n"
    fi
  done
  printf '%s' "${_found# }"
}

# ---------------------------------------------------------------------------
# Transport and headers on one host
# ---------------------------------------------------------------------------
check_host() {
  _host=$1
  _label=$2
  printf '\n== %s: https://%s/\n' "$_label" "$_host"

  if ! fetch "https://$_host/"; then
    finding "no HTTPS response from $_host (name resolution, certificate, or connection failed)"
    return
  fi
  note "status $CODE, $SIZE bytes"

  _v=$(hdr strict-transport-security)
  if [ -z "$_v" ]; then
    finding "Strict-Transport-Security missing"
  else
    note "Strict-Transport-Security: $_v"
    _ma=$(printf '%s' "$_v" | sed -n 's/.*max-age=\([0-9]\{1,\}\).*/\1/p')
    # max-age=0 is not a short policy, it is the off switch: it tells the
    # browser to drop the policy it already stored for this host and to accept
    # plain HTTP again. A shorter but non-zero value is a ramp in progress.
    if [ -n "$_ma" ] && [ "$_ma" -eq 0 ]; then
      finding "Strict-Transport-Security max-age is 0, which turns HSTS off and clears the policy the browser already stored"
    elif [ -n "$_ma" ] && [ "$_ma" -lt 31536000 ]; then
      warn "max-age is $_ma, below the one year (31536000) the playbook asks for"
    fi
  fi

  _csp=$(hdr content-security-policy)
  _cspro=$(hdr content-security-policy-report-only)
  # An enforcing policy is a SHOULD in the playbook, not a MUST, because it
  # takes a report-only rollout to reach. Both the missing case and the
  # report-only case are warnings for that reason: a probe that fails the build
  # over a control the playbook stages is a probe teams stop running.
  if [ -n "$_csp" ]; then
    note "Content-Security-Policy: enforcing"
  elif [ -n "$_cspro" ]; then
    warn "Content-Security-Policy is report-only, which blocks nothing. Confirm the switch date"
  else
    warn "Content-Security-Policy missing, neither enforcing nor report-only. Start the rollout in assets/security-headers.md"
  fi

  for _h in x-content-type-options referrer-policy permissions-policy; do
    _v=$(hdr "$_h")
    if [ -z "$_v" ]; then
      finding "$_h missing"
    else
      note "$_h: $_v"
    fi
  done

  _xfo=$(hdr x-frame-options)
  # Only the enforcing policy is considered here. A report-only policy blocks
  # nothing, so treating it as framing protection would report a control that
  # does not exist.
  case "$_csp" in
    *frame-ancestors*)
      if [ -z "$_xfo" ]; then
        note "x-frame-options absent, covered by frame-ancestors in the policy"
      else
        note "x-frame-options: $_xfo"
      fi
      ;;
    *)
      if [ -z "$_xfo" ]; then
        finding "no framing control: neither x-frame-options nor frame-ancestors"
      else
        note "x-frame-options: $_xfo"
      fi
      ;;
  esac

  # Cross-origin isolation headers, reported and never counted, the same way
  # the content policy above is. assets/security-headers.md stages
  # Cross-Origin-Opener-Policy behind a test of the login flow, because it cuts
  # the window.opener channel a popup identity flow answers through, and
  # Cross-Origin-Resource-Policy is the wrong value for a host other origins are
  # meant to load images, fonts, or scripts from. Both are a decision to read,
  # not a control to assume.
  for _h in cross-origin-opener-policy cross-origin-resource-policy; do
    _v=$(hdr "$_h")
    if [ -z "$_v" ]; then
      note "$_h absent. Confirm that is the intended decision, per \"Safe now, versus observe first\" in assets/security-headers.md"
    else
      note "$_h: $_v"
    fi
  done

  # Version banners (layer 11). A version number is a free lookup of which
  # published vulnerabilities apply.
  for _h in server x-powered-by x-aspnet-version; do
    _v=$(hdr "$_h")
    case "$_v" in
      '') ;;
      *[0-9].[0-9]*) finding "$_h discloses a version: $_v" ;;
      *) note "$_h: $_v" ;;
    esac
  done

  # Recorded before the next fetch overwrites $TMP, and only for the host the
  # path sweep runs against, so the two responses being compared come from the
  # same hostname.
  if [ "$_host" = "$HOST" ]; then
    SUCCESS_HEADERS=$(present_headers)
  fi

  check_cache
}

# ---------------------------------------------------------------------------
# Cache exposure on the last response.
# s-maxage minus Age is how many seconds a shared cache will keep serving this
# object after the origin stops. Purging is enough for a one-off publish; a
# pipeline that republishes the file has to change instead.
# ---------------------------------------------------------------------------
check_cache() {
  _age=$(hdr age)
  _cc=$(hdr cache-control)
  case "$_age" in
    ''|*[!0-9]*) _age='' ;;
  esac
  _smax=$(printf '%s' "$_cc" | sed -n 's/.*s-maxage=\([0-9]\{1,\}\).*/\1/p')
  if [ -n "$_age" ] && [ -n "$_smax" ]; then
    note "cache: Age $_age of s-maxage $_smax, $((_smax - _age)) seconds of exposure remain"
  elif [ -n "$_age" ]; then
    note "cache: Age $_age, no s-maxage declared (Cache-Control: ${_cc:-none})"
  fi
}

# ---------------------------------------------------------------------------
# HTTP to HTTPS
# ---------------------------------------------------------------------------
check_plain_http() {
  _host=$1
  printf '\n== plain HTTP: http://%s/\n' "$_host"
  REQUESTS=$((REQUESTS + 1))
  _code=$(curl -sS -m "$TIMEOUT" -A "$UA" -D "$TMP" -o /dev/null \
          -w '%{http_code}' "http://$_host/" 2>/dev/null)
  _rc=$?
  if [ "$_rc" -ne 0 ]; then
    if curl_exit_is_refusal "$_rc"; then
      note "port 80 refused or filtered, which is acceptable when every visitor arrives over HTTPS"
    else
      unknown "curl exited $_rc against port 80 (timeout, TLS, or local network), so this is not evidence that port 80 is closed. Re-run"
    fi
    return
  fi
  _loc=$(hdr location)
  case "$_code" in
    30*)
      case "$_loc" in
        https://*) note "$_code to $_loc" ;;
        *) finding "$_code to a non-HTTPS target: ${_loc:-no Location header}" ;;
      esac
      ;;
    000) note "no answer on port 80, which is acceptable" ;;
    *) finding "answered $_code over plain HTTP without redirecting to HTTPS" ;;
  esac
}

# ---------------------------------------------------------------------------
# Sensitive paths.
# Single-page applications answer every path with the same fallback page, so a
# 200 alone means nothing. The baseline is a path that certainly does not
# exist: same status and same size means fallback, a different size means a
# real file is being served.
# ---------------------------------------------------------------------------
check_paths() {
  _host=$1
  printf '\n== published artifact: https://%s/\n' "$_host"

  if ! fetch "https://$_host/probe-nonexistent-$$-baseline"; then
    finding "baseline request failed, so the path results below cannot be interpreted"
    return
  fi
  _bcode=$CODE
  _bsize=$SIZE
  note "baseline (a path that does not exist): status $_bcode, $_bsize bytes"

  # The same response answers the second question in the verify block of
  # assets/security-headers.md: nginx skips add_header on 4xx and 5xx without
  # the "always" flag, and an error page is exactly where injected content
  # lands. A header sent on the success response and dropped here is that flag
  # missing on that one line.
  _errhdrs=$(present_headers)
  if [ -z "$_errhdrs" ]; then
    note "security headers on the $_bcode response: none"
  else
    note "security headers on the $_bcode response: $_errhdrs"
  fi
  # The padding on both sides is what keeps one name from matching inside a
  # longer one.
  for _n in $SUCCESS_HEADERS; do
    case " $_errhdrs " in
      *" $_n "*) ;;
      *) finding "$_n is sent on https://$_host/ and not on the $_bcode response for a path that does not exist, which is what a missing \"always\" flag looks like" ;;
    esac
  done

  for _p in .env .env.local .env.production .git/HEAD .git/config package.json \
            composer.json backup.zip dump.sql config.yml docker-compose.yml .DS_Store; do
    if ! fetch "https://$_host/$_p"; then
      note "$_p: request failed"
      continue
    fi
    if [ "$CODE" = "$_bcode" ] && [ "$SIZE" = "$_bsize" ]; then
      note "$_p: $CODE, $SIZE bytes, identical to baseline (fallback page)"
    elif [ "$CODE" -ge 200 ] && [ "$CODE" -lt 300 ]; then
      finding "$_p: $CODE with $SIZE bytes against a $_bsize byte baseline, so a real file is served"
    else
      note "$_p: $CODE, $SIZE bytes"
    fi
  done
}

# ---------------------------------------------------------------------------
# Platform preview host. It bypasses every rule written for the canonical host,
# including the edge configuration, so it must be blocked or password
# protected.
# ---------------------------------------------------------------------------
check_preview() {
  _host=$1
  printf '\n== preview host: https://%s/\n' "$_host"
  if ! fetch "https://$_host/"; then
    # A host that does not resolve or refuses the connection is the result you
    # want. A timeout, a TLS error, or a local network problem says nothing
    # about the preview host, so it is not counted as one.
    if curl_exit_is_refusal "$CURL_EXIT"; then
      note "no DNS record or no connection, which is the outcome you want"
    else
      unknown "curl exited $CURL_EXIT, so the preview host was never reached and this run proves nothing about it. Re-run"
    fi
    return
  fi
  case "$CODE" in
    401|403|404) note "answered $CODE, which is the outcome you want" ;;
    *) finding "answered $CODE and serves $SIZE bytes, so it is a second front door to the same app" ;;
  esac
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
printf 'probe.sh against %s\n' "$HOST"
printf 'Read-only requests. Run this only against systems you operate.\n'

check_host "$HOST" "canonical host"
check_plain_http "$HOST"

if [ "$SECOND" != "$HOST" ]; then
  check_host "$SECOND" "$SECOND_LABEL"
else
  printf '\n== %s\n' "$SECOND_LABEL"
  note "$HOST is already the bare domain and no other hostname was named."
  note "Re-run with a third argument naming the www host, or any other hostname"
  note "that answers, because one answering without the rules above is a bypass."
fi

check_paths "$HOST"

if [ -n "$PREVIEW" ]; then
  check_preview "$PREVIEW"
fi

printf '\n== summary\n'
note "$REQUESTS requests sent"
if [ "$FINDINGS" -eq 0 ]; then
  note 'no findings'
else
  printf '  %s finding(s) above\n' "$FINDINGS"
fi
if [ "$INCONCLUSIVE" -ne 0 ]; then
  printf '  %s check(s) never reached the host, so this run is not a clean bill\n' "$INCONCLUSIVE"
fi

# ---------------------------------------------------------------------------
# Not automated here, because it needs your project's public client credential.
# Run these by hand with that key and nothing else, per verification.md:
#
#   - read a table that should be closed
#   - write to a table that should be closed
#   - read a record belonging to another tenant
#   - list storage buckets and try to read an object
#   - check whether public registration is enabled on the identity module
#   - decode the client token and confirm its lifetime is intentional
#
# Every one must be denied, except where openness is a written product decision.
# The database half of the same question is covered by assets/rls-multitenant.sql
# and assets/tenancy.test.example.ts.
# ---------------------------------------------------------------------------

# 1 for findings, 3 when nothing was found but a check never reached its
# target, 0 only when the run both completed and found nothing.
[ "$FINDINGS" -eq 0 ] || exit 1
[ "$INCONCLUSIVE" -eq 0 ] || exit 3
exit 0
