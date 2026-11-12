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

# Test 1: Fresh SessionStart (Unindexed Conversation)
echo "--- Test 1: SessionStart (Unindexed Conversation) ---"
TTY_MOCK_1=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_1"

INPUT_1='{
  "conversationId": "unindexed-poc-001",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "SessionStart"
}'

OUT_1=$(echo "$INPUT_1" | "$HOOK_BIN")
EXIT_CODE_1=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_1"
assert_valid_json "Stdout schema validation" "$OUT_1"

SYS_MSG_1=$(echo "$OUT_1" | jq -r '.injectSteps[0].systemMessage.systemMessage')
TTY_OUT_1=$(cat "$TTY_MOCK_1")

assert_contains "Badge includes repository folder" "📁 **sandcastles-oh-my-agy**" "$SYS_MSG_1"
assert_contains "Badge includes active git branch" "🌿 \`main\`" "$SYS_MSG_1"
assert_contains "Badge includes clock icon" "⏰" "$SYS_MSG_1"

# Verify OSC 0 sequence in tty mock
assert_contains "TTY window title contains folder and branch" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_1"
assert_eq "TTY output begins with ESC ] 0 ;" "1b5d303b" "$(head -c 4 "$TTY_MOCK_1" | xxd -p)"
rm -f "$TTY_MOCK_1"
echo ""

# Test 2: PreInvocation (Dynamic Refresh on Prompt)
echo "--- Test 2: PreInvocation (Prompt Submission Badge & Sticky Title) ---"
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

SYS_MSG_2=$(echo "$OUT_2" | jq -r '.injectSteps[0].systemMessage.systemMessage')
TTY_OUT_2=$(cat "$TTY_MOCK_2")

assert_contains "PreInvocation badge includes folder" "📁 **sandcastles-oh-my-agy**" "$SYS_MSG_2"
assert_contains "PreInvocation badge includes branch" "🌿 \`main\`" "$SYS_MSG_2"
assert_contains "PreInvocation TTY title set" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_2"
rm -f "$TTY_MOCK_2"
echo ""

# Test 3: PostInvocation with SQLite DB Topic Lookup
echo "--- Test 3: PostInvocation with SQLite DB Topic Lookup ---"
TTY_MOCK_3=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_3"

# Real conversationId from ~/.gemini/antigravity-cli/conversation_summaries.db
INPUT_3='{
  "conversationId": "ecb50299-ff21-43f1-9353-e09135ffb8be",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_3=$(echo "$INPUT_3" | "$HOOK_BIN")
EXIT_CODE_3=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_3"
assert_valid_json "Stdout schema validation" "$OUT_3"

INJECT_STEPS_LEN=$(echo "$OUT_3" | jq '.injectSteps | length')
TERM_BEHAVIOR=$(echo "$OUT_3" | jq -r '.terminationBehavior')
TTY_OUT_3=$(cat "$TTY_MOCK_3")

assert_eq "injectSteps is empty array" "0" "$INJECT_STEPS_LEN"
assert_eq "terminationBehavior is empty string" "" "$TERM_BEHAVIOR"
assert_contains "TTY window title contains resolved SQLite title" "Agy CLI Chat Management Initiative" "$TTY_OUT_3"
rm -f "$TTY_MOCK_3"
echo ""

# Test 4: Workspace Directory Outside Git
echo "--- Test 4: Non-Git Directory Fallback ---"
NON_GIT_DIR=$(mktemp -d /tmp/test-nongit-XXXXXX)
TTY_MOCK_4=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_4"

INPUT_4='{
  "conversationId": "nongit-poc-004",
  "cwd": "'"$NON_GIT_DIR"'",
  "hookEventName": "PreInvocation"
}'

OUT_4=$(echo "$INPUT_4" | "$HOOK_BIN")
EXIT_CODE_4=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_4"
assert_valid_json "Stdout schema validation" "$OUT_4"

SYS_MSG_4=$(echo "$OUT_4" | jq -r '.injectSteps[0].systemMessage.systemMessage')
TTY_OUT_4=$(cat "$TTY_MOCK_4")
NON_GIT_BASE=$(basename "$NON_GIT_DIR")

assert_contains "Badge contains folder name" "📁 **$NON_GIT_BASE**" "$SYS_MSG_4"
if [[ "$SYS_MSG_4" == *"🌿"* ]]; then
  echo "  [FAIL] Badge should not contain git branch icon outside git repo"
  FAILED=$((FAILED + 1))
else
  echo "  [PASS] Badge correctly omits git branch outside git repo"
  PASSED=$((PASSED + 1))
fi

rm -rf "$NON_GIT_DIR" "$TTY_MOCK_4"
echo ""

# Test 5: Fallback to workspacePaths when cwd is omitted
echo "--- Test 5: Fallback to workspacePaths ---"
TTY_MOCK_5=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_5"

INPUT_5='{
  "conversationId": "test-ws-005",
  "workspacePaths": ["'"$PLUGIN_ROOT"'"],
  "hookEventName": "SessionStart"
}'

OUT_5=$(echo "$INPUT_5" | "$HOOK_BIN")
EXIT_CODE_5=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_5"
assert_valid_json "Stdout schema validation" "$OUT_5"

SYS_MSG_5=$(echo "$OUT_5" | jq -r '.injectSteps[0].systemMessage.systemMessage')
assert_contains "Badge resolved folder from workspacePaths" "📁 **sandcastles-oh-my-agy**" "$SYS_MSG_5"
rm -f "$TTY_MOCK_5"
echo ""

# Test 6: Headless & Non-writable TTY Robustness
echo "--- Test 6: Headless & Non-writable TTY Robustness ---"
export OH_MY_AGY_TTY="/dev/nonexistent_tty_device_test"

INPUT_6='{
  "conversationId": "test-headless-006",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_6=$(echo "$INPUT_6" | "$HOOK_BIN" 2>/dev/null)
EXIT_CODE_6=$?

assert_eq "Exit code is 0 when TTY is unwritable" "0" "$EXIT_CODE_6"
assert_valid_json "Stdout schema remains valid JSON in headless mode" "$OUT_6"
echo ""

# Test 7: Empty input payload
echo "--- Test 7: Empty Input Handling ---"
unset OH_MY_AGY_TTY
OUT_7=$(echo "" | "$HOOK_BIN" 2>/dev/null)
EXIT_CODE_7=$?

assert_eq "Exit code is 0 on empty stdin" "0" "$EXIT_CODE_7"
assert_valid_json "Stdout remains valid JSON on empty stdin" "$OUT_7"
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
