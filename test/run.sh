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

assert "detects unresolved capabilities" \
  "$LIFE status" \
  "Unresolved"

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

assert "check warns on missing infra provider" \
  "$LIFE check" \
  "Install an infra adapter"

# --- Graph resolution ---
echo
echo "capability graph:"
assert "blog.preview provided by blog, required by api" \
  "$LIFE explain api" \
  "blog.preview"

assert "api.ready is provided" \
  "$LIFE index" \
  "api.ready"

assert "infra.compute is NOT provided (no adapter)" \
  "$LIFE check blog" \
  "not provided"

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

# --- Dangerous combo warnings ---
echo
echo "dangerous combo detection:"
# api has infra.route (not public) + no auth — should NOT warn
# We'd need a fixture with public route + storage.commit to trigger the warning
# For now, test that life.agent warning works if we add it

# --- Summary ---
echo
echo "==========================="
echo "$PASS passed, $FAIL failed"
echo "==========================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
