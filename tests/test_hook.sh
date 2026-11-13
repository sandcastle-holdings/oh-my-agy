#!/usr/bin/env bash
# Test Suite: oh-my-agy Hook Verification (Tab-Only Mode)
# Engineered by Alex Seif and Sandcastle Holdings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_BIN="$PLUGIN_ROOT/scripts/title_and_badge.sh"

PASSED=0
FAILED=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  [PASS] $label"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $label"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    FAILED=$((FAILED + 1))
  fi
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  [PASS] $label"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $label"
    echo "    Expected substring: $needle"
    echo "    In output:          $haystack"
    FAILED=$((FAILED + 1))
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  [PASS] $label"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $label"
    echo "    Unexpected substring found: $needle"
    echo "    In output:                  $haystack"
    FAILED=$((FAILED + 1))
  fi
}

assert_valid_json() {
  local label="$1"
  local json_str="$2"
  if echo "$json_str" | jq empty >/dev/null 2>&1; then
    echo "  [PASS] $label (valid JSON)"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $label (malformed JSON)"
    echo "    Raw: $json_str"
    FAILED=$((FAILED + 1))
  fi
}

# Asserts that the file contains ONLY an OSC 0 sequence (\033]0;...\007) and zero viewport text
assert_osc0_only() {
  local label="$1"
  local file="$2"
  local first_byte
  local last_byte
  
  if [ ! -s "$file" ]; then
    echo "  [FAIL] $label: file is empty"
    FAILED=$((FAILED + 1))
    return
  fi

  first_bytes=$(head -c 4 "$file" | xxd -p)
  last_byte=$(tail -c 1 "$file" | xxd -p)

  if [ "$first_bytes" = "1b5d303b" ] && [ "$last_byte" = "07" ]; then
    echo "  [PASS] $label: strictly wrapped in OSC 0 delimiters (\\033]0; ... \\007)"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] $label: invalid delimiters (first: $first_bytes, last: $last_byte)"
    FAILED=$((FAILED + 1))
  fi
}

echo "=== Running oh-my-agy Test Suite (Tab-Only Mode) ==="
echo "Target script: $HOOK_BIN"
echo ""

# Test 1: SessionStart (Initial Title, Zero Viewport Interference)
echo "--- Test 1: SessionStart (Initial Window Title) ---"
TTY_MOCK_1=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_1"
unset OH_MY_AGY_CONFIG 2>/dev/null || true

INPUT_1='{
  "conversationId": "unindexed-poc-001",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "SessionStart"
}'

OUT_1=$(echo "$INPUT_1" | "$HOOK_BIN")
EXIT_CODE_1=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_1"
assert_valid_json "Stdout schema validation" "$OUT_1"

INJECT_LEN_1=$(echo "$OUT_1" | jq '.injectSteps | length')
TTY_OUT_1=$(cat "$TTY_MOCK_1")

assert_eq "SessionStart injectSteps is empty array" "0" "$INJECT_LEN_1"
assert_contains "TTY window title contains folder and branch" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_1"
assert_osc0_only "TTY output contains exclusively OSC 0 escape code" "$TTY_MOCK_1"
assert_not_contains "TTY contains zero viewport divider text" "── 📁" "$TTY_OUT_1"
rm -f "$TTY_MOCK_1"
echo ""

# Test 2: PreInvocation (Dynamic Title Refresh on Prompt)
echo "--- Test 2: PreInvocation (Sticky Title Refresh) ---"
TTY_MOCK_2=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_2"

INPUT_2='{
  "conversationId": "unindexed-poc-002",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PreInvocation"
}'

OUT_2=$(echo "$INPUT_2" | "$HOOK_BIN")
EXIT_CODE_2=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_2"
assert_valid_json "Stdout schema validation" "$OUT_2"

INJECT_LEN_2=$(echo "$OUT_2" | jq '.injectSteps | length')
TTY_OUT_2=$(cat "$TTY_MOCK_2")

assert_eq "PreInvocation injectSteps is empty array" "0" "$INJECT_LEN_2"
assert_contains "PreInvocation TTY title refreshed" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_2"
assert_osc0_only "PreInvocation TTY is strictly OSC 0 escape code" "$TTY_MOCK_2"
assert_not_contains "PreInvocation contains zero viewport divider text" "── 📁" "$TTY_OUT_2"
rm -f "$TTY_MOCK_2"
echo ""

# Test 3: PostInvocation (Title Updated with SQLite Topic, Zero Injected Messages)
echo "--- Test 3: PostInvocation (Topic Resolution) ---"
TTY_MOCK_3=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_3"

INPUT_3='{
  "conversationId": "ecb50299-ff21-43f1-9353-e09135ffb8be",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_3=$(echo "$INPUT_3" | "$HOOK_BIN")
EXIT_CODE_3=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_3"
assert_valid_json "Stdout schema validation" "$OUT_3"

INJECT_LEN_3=$(echo "$OUT_3" | jq '.injectSteps | length')
TTY_OUT_3=$(cat "$TTY_MOCK_3")

assert_eq "PostInvocation injectSteps is empty array (zero trajectory pollution)" "0" "$INJECT_LEN_3"
assert_contains "TTY window title updated with resolved SQLite topic" "Agy CLI Chat Management Initiative" "$TTY_OUT_3"
assert_osc0_only "PostInvocation TTY is strictly OSC 0 escape code" "$TTY_MOCK_3"
assert_not_contains "PostInvocation contains zero viewport divider text" "── 📁" "$TTY_OUT_3"
rm -f "$TTY_MOCK_3"
echo ""

# Test 4: Workspace Outside Git
echo "--- Test 4: Non-Git Directory Fallback ---"
NON_GIT_DIR=$(mktemp -d /tmp/test-nongit-XXXXXX)
TTY_MOCK_4=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_4"

INPUT_4='{
  "conversationId": "nongit-poc-004",
  "cwd": "'"$NON_GIT_DIR"'",
  "hookEventName": "PostInvocation"
}'

OUT_4=$(echo "$INPUT_4" | "$HOOK_BIN")
EXIT_CODE_4=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_4"
assert_valid_json "Stdout schema validation" "$OUT_4"

INJECT_LEN_4=$(echo "$OUT_4" | jq '.injectSteps | length')
TTY_OUT_4=$(cat "$TTY_MOCK_4")
NON_GIT_BASE=$(basename "$NON_GIT_DIR")

assert_eq "Non-git injectSteps is empty array" "0" "$INJECT_LEN_4"
assert_contains "TTY title contains folder name" "[$NON_GIT_BASE]" "$TTY_OUT_4"
assert_not_contains "TTY title omits branch colon outside git" "[$NON_GIT_BASE:" "$TTY_OUT_4"

rm -rf "$NON_GIT_DIR" "$TTY_MOCK_4"
echo ""

# Test 5: Fallback to workspacePaths
echo "--- Test 5: Fallback to workspacePaths ---"
TTY_MOCK_5=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_5"

INPUT_5='{
  "conversationId": "test-ws-005",
  "workspacePaths": ["'"$PLUGIN_ROOT"'"],
  "hookEventName": "PostInvocation"
}'

OUT_5=$(echo "$INPUT_5" | "$HOOK_BIN")
EXIT_CODE_5=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_5"
assert_valid_json "Stdout schema validation" "$OUT_5"

TTY_OUT_5=$(cat "$TTY_MOCK_5")
assert_contains "TTY title resolved folder from workspacePaths" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_5"
rm -f "$TTY_MOCK_5"
echo ""

# Test 6: Configuration Overrides (show_title: false)
echo "--- Test 6: Configuration Override (show_title: false) ---"
CFG_FILE_DISABLE_TITLE=$(mktemp)
echo '{"show_title": false}' > "$CFG_FILE_DISABLE_TITLE"
TTY_MOCK_6=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_6"
export OH_MY_AGY_CONFIG="$CFG_FILE_DISABLE_TITLE"

INPUT_6='{
  "conversationId": "test-cfg-006",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_6=$(echo "$INPUT_6" | "$HOOK_BIN")
TTY_OUT_6=$(cat "$TTY_MOCK_6")

assert_eq "TTY is completely empty when show_title=false" "" "$TTY_OUT_6"
rm -f "$CFG_FILE_DISABLE_TITLE" "$TTY_MOCK_6"
unset OH_MY_AGY_CONFIG
echo ""

# Test 7: Headless & Non-writable TTY Robustness
echo "--- Test 7: Headless & Non-writable TTY Robustness ---"
export OH_MY_AGY_TTY="/dev/nonexistent_tty_device_test"

INPUT_7='{
  "conversationId": "test-headless-007",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_7=$(echo "$INPUT_7" | "$HOOK_BIN" 2>/dev/null)
EXIT_CODE_7=$?

assert_eq "Exit code is 0 when TTY is unwritable" "0" "$EXIT_CODE_7"
assert_valid_json "Stdout schema remains valid JSON in headless mode" "$OUT_7"
echo ""

# Test 8: Empty input payload
echo "--- Test 8: Empty Input Handling ---"
unset OH_MY_AGY_TTY
OUT_8=$(echo "" | "$HOOK_BIN" 2>/dev/null)
EXIT_CODE_8=$?

assert_eq "Exit code is 0 on empty stdin" "0" "$EXIT_CODE_8"
assert_valid_json "Stdout remains valid JSON on empty stdin" "$OUT_8"
echo ""

# Summary
echo "=== Test Summary ==="
echo "Total Passed: $PASSED"
echo "Total Failed: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  echo "Result: ALL TESTS PASSED SUCCESSFULLY."
  exit 0
else
  echo "Result: TEST FAILURES DETECTED."
  exit 1
fi
