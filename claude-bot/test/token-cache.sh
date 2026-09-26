#!/usr/bin/env bash
# Minting for two owners gives two tokens in two cache files, and a repeat
# call for the same owner is served from cache without hitting the API.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
token_cmd=$here/../bin/claude-bot-token

work=$(mktemp -d "${TMPDIR:-/tmp}/claude-bot-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

openssl genrsa -out "$work/key.pem" 2048 2>/dev/null

# Fake curl: logs each request and answers like the GitHub API.
mkdir "$work/bin"
cat >"$work/bin/curl" <<'STUB'
#!/usr/bin/env bash
method=GET out= url=
while [ $# -gt 0 ]; do
  case $1 in
    -X) method=$2; shift ;;
    -o) out=$2; shift ;;
    -H | -w) shift ;;
    -*) ;;
    *) url=$1 ;;
  esac
  shift
done
cat >/dev/null
printf '%s %s\n' "$method" "$url" >>"$STUB_LOG"
case "$method $url" in
  "GET "*/orgs/acme/installation) body='{"id":11}' status=200 ;;
  "GET "*/orgs/*/installation) body='{"message":"Not Found"}' status=404 ;;
  "GET "*/users/alice/installation) body='{"id":22}' status=200 ;;
  "POST "*/app/installations/*/access_tokens)
    id=${url%/access_tokens}; id=${id##*/}
    body="{\"token\":\"ghs_$id\",\"expires_at\":\"2099-01-01T00:00:00Z\"}" status=201 ;;
  *) body='{"message":"Not Found"}' status=404 ;;
esac
printf '%s' "$body" >"$out"
printf '%s' "$status"
STUB
chmod +x "$work/bin/curl"

export PATH="$work/bin:$PATH"
export STUB_LOG=$work/requests.log
export CLAUDE_BOT_KEY=$work/key.pem
export CLAUDE_BOT_CACHE=$work/cache
export CLAUDE_BOT_API=https://api.test
: >"$STUB_LOG"

t_alice=$("$token_cmd" alice)
t_acme=$("$token_cmd" acme)

[ -n "$t_alice" ] && [ -n "$t_acme" ] || fail "empty token"
[ "$t_alice" != "$t_acme" ] || fail "both owners got the same token: $t_alice"
[ -f "$CLAUDE_BOT_CACHE/token-alice.json" ] || fail "no cache file for alice"
[ -f "$CLAUDE_BOT_CACHE/token-acme.json" ] || fail "no cache file for acme"

hits=$(wc -l <"$STUB_LOG")
[ "$hits" -gt 0 ] || fail "stub API was never called"

t_again=$("$token_cmd" alice)
[ "$t_again" = "$t_alice" ] || fail "second call returned a different token"
[ "$(wc -l <"$STUB_LOG")" -eq "$hits" ] || fail "second call hit the API: $(tail -n 1 "$STUB_LOG")"

echo "PASS: token-cache"
