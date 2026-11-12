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

# Test 1: Fresh Session without DB entry (SessionStart fallback)
echo "--- Test 1: Fresh SessionStart (Unindexed Conversation) ---"
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
USER_MD_1=$(echo "$OUT_1" | jq -r '.injectSteps[0].systemMessage.metadata.user_markdown')
TTY_OUT_1=$(cat "$TTY_MOCK_1")

assert_eq "systemMessage text is empty string (zero LLM token pollution)" "" "$SYS_MSG_1"
assert_contains "Badge includes repository folder" "📁 **sandcastles-oh-my-agy**" "$USER_MD_1"
assert_contains "Badge includes active git branch" "🌿 \`main\`" "$USER_MD_1"
assert_contains "Badge includes clock icon" "⏰" "$USER_MD_1"

# Verify OSC 0 sequence in tty mock
assert_contains "TTY window title contains folder and branch" "[sandcastles-oh-my-agy:main]" "$TTY_OUT_1"
assert_eq "TTY output begins with ESC ] 0 ;" "1b5d303b" "$(head -c 4 "$TTY_MOCK_1" | xxd -p)"
rm -f "$TTY_MOCK_1"
echo ""

# Test 2: Ongoing Session with DB Topic (PostInvocation)
echo "--- Test 2: PostInvocation with SQLite DB Topic Lookup ---"
TTY_MOCK_2=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_2"

# Real conversationId from ~/.gemini/antigravity-cli/conversation_summaries.db
INPUT_2='{
  "conversationId": "ecb50299-ff21-43f1-9353-e09135ffb8be",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_2=$(echo "$INPUT_2" | "$HOOK_BIN")
EXIT_CODE_2=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_2"
assert_valid_json "Stdout schema validation" "$OUT_2"

USER_MD_2=$(echo "$OUT_2" | jq -r '.injectSteps[0].systemMessage.metadata.user_markdown')
TTY_OUT_2=$(cat "$TTY_MOCK_2")

assert_contains "Badge contains resolved SQLite title" "💬 *Agy CLI Chat Management Initiative*" "$USER_MD_2"
assert_contains "TTY window title contains resolved SQLite title" "Agy CLI Chat Management Initiative" "$TTY_OUT_2"
rm -f "$TTY_MOCK_2"
echo ""

# Test 3: Workspace Directory Outside Git
echo "--- Test 3: Non-Git Directory Fallback ---"
NON_GIT_DIR=$(mktemp -d /tmp/test-nongit-XXXXXX)
TTY_MOCK_3=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_3"

INPUT_3='{
  "conversationId": "nongit-poc-003",
  "cwd": "'"$NON_GIT_DIR"'",
  "hookEventName": "SessionStart"
}'

OUT_3=$(echo "$INPUT_3" | "$HOOK_BIN")
EXIT_CODE_3=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_3"
assert_valid_json "Stdout schema validation" "$OUT_3"

USER_MD_3=$(echo "$OUT_3" | jq -r '.injectSteps[0].systemMessage.metadata.user_markdown')
TTY_OUT_3=$(cat "$TTY_MOCK_3")
NON_GIT_BASE=$(basename "$NON_GIT_DIR")

assert_contains "Badge contains folder name" "📁 **$NON_GIT_BASE**" "$USER_MD_3"
if [[ "$USER_MD_3" == *"🌿"* ]]; then
  echo "  [FAIL] Badge should not contain git branch icon outside git repo"
  FAILED=$((FAILED + 1))
else
  echo "  [PASS] Badge correctly omits git branch outside git repo"
  PASSED=$((PASSED + 1))
fi

rm -rf "$NON_GIT_DIR" "$TTY_MOCK_3"
echo ""

# Test 4: Fallback to workspacePaths when cwd is omitted
echo "--- Test 4: Fallback to workspacePaths ---"
TTY_MOCK_4=$(mktemp)
export OH_MY_AGY_TTY="$TTY_MOCK_4"

INPUT_4='{
  "conversationId": "test-ws-004",
  "workspacePaths": ["'"$PLUGIN_ROOT"'"],
  "hookEventName": "SessionStart"
}'

OUT_4=$(echo "$INPUT_4" | "$HOOK_BIN")
EXIT_CODE_4=$?

assert_eq "Exit code is 0" "0" "$EXIT_CODE_4"
assert_valid_json "Stdout schema validation" "$OUT_4"

USER_MD_4=$(echo "$OUT_4" | jq -r '.injectSteps[0].systemMessage.metadata.user_markdown')
assert_contains "Badge resolved folder from workspacePaths" "📁 **sandcastles-oh-my-agy**" "$USER_MD_4"
rm -f "$TTY_MOCK_4"
echo ""

# Test 5: Headless / Unattached / Non-writable TTY
echo "--- Test 5: Headless & Non-writable TTY Robustness ---"
export OH_MY_AGY_TTY="/dev/nonexistent_tty_device_test"

INPUT_5='{
  "conversationId": "test-headless-005",
  "cwd": "'"$PLUGIN_ROOT"'",
  "hookEventName": "PostInvocation"
}'

OUT_5=$(echo "$INPUT_5" | "$HOOK_BIN" 2>/dev/null)
EXIT_CODE_5=$?

assert_eq "Exit code is 0 when TTY is unwritable" "0" "$EXIT_CODE_5"
assert_valid_json "Stdout schema remains valid JSON in headless mode" "$OUT_5"
echo ""

# Test 6: Empty input payload
echo "--- Test 6: Empty Input Handling ---"
unset OH_MY_AGY_TTY
OUT_6=$(echo "" | "$HOOK_BIN" 2>/dev/null)
EXIT_CODE_6=$?

assert_eq "Exit code is 0 on empty stdin" "0" "$EXIT_CODE_6"
assert_valid_json "Stdout remains valid JSON on empty stdin" "$OUT_6"
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
