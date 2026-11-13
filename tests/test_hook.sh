#!/usr/bin/env bash
# Test Suite: oh-my-agy Hook Verification
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

echo "=== Running oh-my-agy Test Suite ==="
echo "Target script: $HOOK_BIN"
echo ""

# Test 1: SessionStart (Initial Title, Empty injectSteps)
echo "--- Test 1: SessionStart (Initial Title, Empty injectSteps) ---"
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
assert_eq "TTY output begins with ESC ] 0 ;" "1b5d303b" "$(head -c 4 "$TTY_MOCK_1" | xxd -p)"
assert_not_contains "SessionStart does not output footer divider" "── 📁" "$TTY_OUT_1"
rm -f "$TTY_MOCK_1"
echo ""

# Test 2: PreInvocation (Sticky Title Refresh, Empty injectSteps)
echo "--- Test 2: PreInvocation (Sticky Title Refresh, Empty injectSteps) ---"
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

assert_eq "PreInvocation injectSteps is empty array (no prompt pollution)" "0" "$INJECT_LEN_2"
assert_contains "PreInvocation TTY title refreshed" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_2"
assert_not_contains "PreInvocation does not output footer divider" "── 📁" "$TTY_OUT_2"
rm -f "$TTY_MOCK_2"
echo ""

# Test 3: PostInvocation (Visible TTY Footer Divider + Response Badge)
echo "--- Test 3: PostInvocation (Visible TTY Footer Divider + Response Badge) ---"
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

SYS_MSG_3=$(echo "$OUT_3" | jq -r '.injectSteps[0].systemMessage.systemMessage')
TTY_OUT_3=$(cat "$TTY_MOCK_3")

assert_contains "PostInvocation badge contains folder" "📁 **sandcastles-oh-my-agy**" "$SYS_MSG_3"
assert_contains "PostInvocation badge contains branch" "🌿 \`main\`" "$SYS_MSG_3"
assert_contains "PostInvocation badge contains SQLite topic" "💬 *Agy CLI Chat Management Initiative*" "$SYS_MSG_3"

# Verify TTY title and visible divider
assert_contains "TTY window title updated with topic" "Agy CLI Chat Management Initiative" "$TTY_OUT_3"
assert_contains "TTY received visible footer divider" "── 📁 sandcastles-oh-my-agy | 🌿 main | 💬 Agy CLI Chat Management Initiative" "$TTY_OUT_3"
rm -f "$TTY_MOCK_3"
echo ""

# Test 4: Workspace Outside Git
echo "--- Test 4: Workspace Outside Git ---"
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

SYS_MSG_4=$(echo "$OUT_4" | jq -r '.injectSteps[0].systemMessage.systemMessage')
TTY_OUT_4=$(cat "$TTY_MOCK_4")
NON_GIT_BASE=$(basename "$NON_GIT_DIR")

assert_contains "Badge contains folder name" "📁 **$NON_GIT_BASE**" "$SYS_MSG_4"
assert_not_contains "Badge omits branch icon outside git" "🌿" "$SYS_MSG_4"
assert_contains "TTY footer contains folder name" "── 📁 $NON_GIT_BASE" "$TTY_OUT_4"
assert_not_contains "TTY footer omits branch icon outside git" "🌿" "$TTY_OUT_4"

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

SYS_MSG_5=$(echo "$OUT_5" | jq -r '.injectSteps[0].systemMessage.systemMessage')
assert_contains "Badge resolved folder from workspacePaths" "📁 **sandcastles-oh-my-agy**" "$SYS_MSG_5"
rm -f "$TTY_MOCK_5"
echo ""

# Test 6: Configuration Overrides (show_footer: false, show_title: false)
echo "--- Test 6: Configuration Overrides (~/.config/oh-my-agy/config.json) ---"
CFG_FILE_DISABLE_FOOTER=$(mktemp)
echo '{"show_footer": false, "show_title": true}' > "$CFG_FILE_DISABLE_FOOTER"
TTY_MOCK_6A=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_6A"
export OH_MY_AGY_CONFIG="$CFG_FILE_DISABLE_FOOTER"

INPUT_6A='{
  "conversationId": "test-cfg-006a",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_6A=$(echo "$INPUT_6A" | "$HOOK_BIN")
TTY_OUT_6A=$(cat "$TTY_MOCK_6A")

assert_not_contains "TTY footer is omitted when show_footer=false" "── 📁" "$TTY_OUT_6A"
assert_contains "TTY window title is still emitted when show_title=true" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_6A"
rm -f "$CFG_FILE_DISABLE_FOOTER" "$TTY_MOCK_6A"

# Test show_title: false
CFG_FILE_DISABLE_TITLE=$(mktemp)
echo '{"show_footer": true, "show_title": false}' > "$CFG_FILE_DISABLE_TITLE"
TTY_MOCK_6B=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_6B"
export OH_MY_AGY_CONFIG="$CFG_FILE_DISABLE_TITLE"

OUT_6B=$(echo "$INPUT_6A" | "$HOOK_BIN")
TTY_OUT_6B=$(cat "$TTY_MOCK_6B")

assert_not_contains "TTY title is omitted when show_title=false" $'\033]0;' "$TTY_OUT_6B"
assert_contains "TTY footer is still emitted when show_footer=true" "── 📁" "$TTY_OUT_6B"
rm -f "$CFG_FILE_DISABLE_TITLE" "$TTY_MOCK_6B"
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
