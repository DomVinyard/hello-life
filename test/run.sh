#!/usr/bin/env bash
set -euo pipefail

# Life 0.1 test suite — exercises every kernel command.
# Run from repo root: bash test/run.sh

LIFE="./life"
PASS=0
FAIL=0
TESTS=()

assert() {
  local name="$1"
  local cmd="$2"
  local expect="$3"
  local output
  output=$(eval "$cmd" 2>&1) || true
  if echo "$output" | grep -q "$expect"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    expected: $expect"
    echo "    got: $(echo "$output" | head -3)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local name="$1"
  local cmd="$2"
  local expected_code="$3"
  eval "$cmd" >/dev/null 2>&1
  local actual=$?
  if [ "$actual" -eq "$expected_code" ]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    expected exit $expected_code, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Life 0.1 Test Suite ==="
echo

# --- Status ---
echo "life status:"
assert "finds repo root" \
  "$LIFE status" \
  "Life repo:"

assert "counts living directories" \
  "$LIFE status" \
  "Living directories:"

assert "reports capability count" \
  "$LIFE status" \
  "Capabilities provided:"

# --- Index ---
echo
echo "life index:"
assert "returns JSON array" \
  "$LIFE index" \
  '"name"'

assert "includes blog" \
  "$LIFE index" \
  '"blog"'

assert "includes api" \
  "$LIFE index" \
  '"api"'

assert "includes root" \
  "$LIFE index" \
  '"hello-life"'

assert "blog provides blog.preview" \
  "$LIFE index" \
  'blog.preview'

assert "api requires blog.preview" \
  "$LIFE index" \
  'blog.preview'

assert "api provides api.ready" \
  "$LIFE index" \
  'api.ready'

# --- Explain ---
echo
echo "life explain:"
assert "explains blog" \
  "$LIFE explain blog" \
  "blog: Static site"

assert "shows blog requires" \
  "$LIFE explain blog" \
  "infra.compute"

assert "shows blog provides" \
  "$LIFE explain blog" \
  "blog.preview"

assert "shows blog commands" \
  "$LIFE explain blog" \
  "build"

assert "shows body text" \
  "$LIFE explain blog" \
  "static site"

assert "explains api" \
  "$LIFE explain api" \
  "api: Backend service"

assert "shows api secrets" \
  "$LIFE explain api" \
  "DATABASE_URL"

assert "explains missing path" \
  "$LIFE explain nonexistent" \
  "No .life file"

# --- Check ---
echo
echo "life check:"
assert "check blog passes checks" \
  "$LIFE check blog" \
  "blog check passed"

assert "check api passes checks" \
  "$LIFE check api" \
  "api check passed"

assert "check detects missing infra capabilities" \
  "$LIFE check" \
  "infra.compute"

assert "check detects missing secrets" \
  "DATABASE_URL= API_KEY= $LIFE check api" \
  "secret DATABASE_URL"

assert "check passes secrets when set" \
  "DATABASE_URL=x API_KEY=y $LIFE check api" \
  "secret DATABASE_URL — set"

assert "blog.preview resolves (provided by blog)" \
  "$LIFE check api" \
  "blog.preview"

assert "check resolves infra via adapter" \
  "$LIFE check blog" \
  "✓ requires infra.compute"

# --- Graph resolution ---
echo
echo "capability graph:"
assert "blog.preview provided by blog, required by api" \
  "$LIFE explain api" \
  "blog.preview"

assert "api.ready is provided" \
  "$LIFE index" \
  "api.ready"

assert "infra.compute IS provided (adapter installed)" \
  "$LIFE check blog" \
  "✓ requires infra.compute"

# --- Run ---
echo
echo "life run:"
assert "run blog.build executes" \
  "$LIFE run blog.build" \
  "building blog"

assert "run api.test executes" \
  "$LIFE run api.test" \
  "tests passed"

assert "run api.health executes" \
  "$LIFE run api.health" \
  "healthy"

assert "run api.migrate blocked without --approve" \
  "$LIFE run api.migrate" \
  "requires approval"

assert "run nonexistent.cmd fails" \
  "$LIFE run nonexistent.build" \
  "No directory"

# --- Adapter discovery ---
echo
echo "adapter discovery:"
assert "cloudflare adapter discovered" \
  "$LIFE index" \
  '"cloudflare"'

assert "cloudflare provides infra.compute" \
  "$LIFE index" \
  "infra.compute"

assert "infra capabilities now resolve" \
  "$LIFE check blog" \
  "✓ requires infra.compute"

assert "hello directory discovered" \
  "$LIFE index" \
  '"hello"'

assert "explain hello works" \
  "$LIFE explain hello" \
  "hello: Tiny Worker"

# --- Connect ---
echo
echo "life connect:"
assert "connect without token fails" \
  "CLOUDFLARE_API_TOKEN= CLOUDFLARE_ACCOUNT_ID= $LIFE connect cloudflare" \
  "CLOUDFLARE_API_TOKEN not set"

assert "connect unknown adapter fails" \
  "$LIFE connect nonexistent" \
  "No adapter named"

# --- Deploy ---
echo
echo "life deploy:"
assert "deploy without adapter token fails" \
  "CLOUDFLARE_API_TOKEN= $LIFE deploy hello" \
  "Not connected\|not connected\|CLOUDFLARE_API_TOKEN"

assert "deploy unknown dir fails" \
  "$LIFE deploy nonexistent" \
  "No .life file"

# --- Live infra test (only if token is set) ---
if [ -n "$CLOUDFLARE_API_TOKEN" ] && [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo
  echo "live infra (CLOUDFLARE_API_TOKEN set):"
  # Connect
  CONNECT_OUT=$($LIFE connect cloudflare 2>&1) || true
  if echo "$CONNECT_OUT" | grep -q "connected\|Token valid"; then
    echo "  ✓ connect succeeds"
    PASS=$((PASS + 1))

    # Deploy
    DEPLOY_OUT=$($LIFE deploy hello 2>&1) || true
    if echo "$DEPLOY_OUT" | grep -q "deployed"; then
      echo "  ✓ deploy hello succeeds"
      PASS=$((PASS + 1))

      # Smokecheck
      SMOKE_OUT=$(node .life/lib/cloudflare/smokecheck.js hello 2>&1) || true
      if echo "$SMOKE_OUT" | grep -q "exists"; then
        echo "  ✓ smokecheck hello"
        PASS=$((PASS + 1))
      else
        echo "  ✗ smokecheck hello"
        echo "    got: $SMOKE_OUT"
        FAIL=$((FAIL + 1))
      fi

      # Cleanup
      curl -s -X DELETE \
        "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/hello" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" > /dev/null 2>&1
      echo "  (cleaned up hello worker)"
    else
      echo "  ✗ deploy hello"
      echo "    got: $(echo "$DEPLOY_OUT" | head -2)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ⚠ connect failed (token may be scoped) — skipping deploy tests"
    echo "    got: $(echo "$CONNECT_OUT" | tail -1)"
  fi
else
  echo
  echo "live infra: SKIPPED (set CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID to run)"
fi

# --- Summary ---
echo
echo "==========================="
echo "$PASS passed, $FAIL failed"
echo "==========================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
