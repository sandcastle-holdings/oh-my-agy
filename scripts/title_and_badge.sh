#!/usr/bin/env bash
# oh-my-agy: dynamic terminal title and statusline badge for Google Antigravity
# Engineered by Alex Seif and Sandcastle Holdings

set -o pipefail

# Read JSON payload from stdin
input_json=$(cat)
if [ -z "$input_json" ]; then
  input_json="{}"
fi

# Extract fields via jq if available
conversation_id=""
cwd_path=""
workspace_path=""
event_name=""

if command -v jq >/dev/null 2>&1; then
  conversation_id=$(echo "$input_json" | jq -r '.conversationId // empty' 2>/dev/null || true)
  cwd_path=$(echo "$input_json" | jq -r '.cwd // empty' 2>/dev/null || true)
  workspace_path=$(echo "$input_json" | jq -r '.workspacePaths[0] // empty' 2>/dev/null || true)
  event_name=$(echo "$input_json" | jq -r '.hookEventName // empty' 2>/dev/null || true)
fi

# Configuration options (from ~/.config/oh-my-agy/config.json)
config_file="${OH_MY_AGY_CONFIG:-$HOME/.config/oh-my-agy/config.json}"
show_footer="true"
show_title="true"

if [ -f "$config_file" ] && command -v jq >/dev/null 2>&1; then
  cfg_footer=$(jq -r 'if .show_footer == false then "false" elif .show_footer == true then "true" else empty end' "$config_file" 2>/dev/null || true)
  if [ "$cfg_footer" = "false" ]; then
    show_footer="false"
  fi
  cfg_title=$(jq -r 'if .show_title == false then "false" elif .show_title == true then "true" else empty end' "$config_file" 2>/dev/null || true)
  if [ "$cfg_title" = "false" ]; then
    show_title="false"
  fi
fi

# Determine active target directory and folder name
target_dir="${cwd_path:-${workspace_path:-$PWD}}"
if [ ! -d "$target_dir" ]; then
  target_dir="$PWD"
fi
folder_name=$(basename "$target_dir")

# Determine git branch if inside a git repository
git_branch=""
if command -v git >/dev/null 2>&1; then
  git_branch=$(git -C "$target_dir" branch --show-current 2>/dev/null || true)
  if [ -z "$git_branch" ]; then
    git_branch=$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  fi
  if [ "$git_branch" = "HEAD" ]; then
    git_branch=$(git -C "$target_dir" rev-parse --short HEAD 2>/dev/null || true)
  fi
fi

# Look up or format conversation topic/title
current_time=$(date +"%H:%M")
topic=""

if [ -n "$conversation_id" ] && command -v sqlite3 >/dev/null 2>&1; then
  db_file=""
  if [ -f "$HOME/.gemini/antigravity-cli/conversation_summaries.db" ]; then
    db_file="$HOME/.gemini/antigravity-cli/conversation_summaries.db"
  elif [ -f "$HOME/.gemini/antigravity/conversation_summaries.db" ]; then
    db_file="$HOME/.gemini/antigravity/conversation_summaries.db"
  fi

  if [ -n "$db_file" ]; then
    sanitized_id=$(echo "$conversation_id" | tr -cd 'a-zA-Z0-9_-')
    if [ -n "$sanitized_id" ]; then
      topic=$(sqlite3 "$db_file" "SELECT title FROM conversation_summaries WHERE conversation_id = '$sanitized_id' LIMIT 1;" 2>/dev/null || true)
    fi
  fi
fi

# Determine display topic and fallback
if [ -n "$topic" ]; then
  display_topic="$topic"
else
  if [ -n "$git_branch" ]; then
    display_topic="${folder_name} (${git_branch}) @ ${current_time}"
  else
    display_topic="${folder_name} @ ${current_time}"
  fi
fi

# Format window title: [<folder>:<branch>] <topic>
if [ -n "$git_branch" ]; then
  window_title="[${folder_name}:${git_branch}] ${display_topic}"
else
  window_title="[${folder_name}] ${display_topic}"
fi

# Support OH_MY_AGY_TTY override for testing environments
tty_device="${OH_MY_AGY_TTY:-/dev/tty}"

# Emit OSC 0 escape sequence to tty if writable and enabled
if [ "$show_title" = "true" ] && [ -w "$tty_device" ]; then
  printf '\033]0;%s\007' "$window_title" >> "$tty_device" 2>/dev/null || true
fi

# Build badge representations
branch_badge_tty=""
branch_badge_md=""
if [ -n "$git_branch" ]; then
  branch_badge_tty=" | 🌿 ${git_branch}"
  branch_badge_md=" | 🌿 \`${git_branch}\`"
fi

topic_badge_tty=""
topic_badge_md=""
if [ -n "$topic" ]; then
  topic_badge_tty=" | 💬 ${topic}"
  topic_badge_md=" | 💬 *${topic}*"
fi

badge="📁 **${folder_name}**${branch_badge_md}${topic_badge_md} | ⏰ ${current_time}"

# Output response based on event type
if [ "$event_name" = "PostInvocation" ]; then
  # Print visible footer directly to TTY if writable and enabled
  if [ "$show_footer" = "true" ] && [ -w "$tty_device" ]; then
    printf '\n\033[90m── 📁 %s%s%s | ⏰ %s ──\033[0m\n\n' "$folder_name" "$branch_badge_tty" "$topic_badge_tty" "$current_time" >> "$tty_device" 2>/dev/null || true
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg badge "$badge" '{
      "injectSteps": [
        {
          "systemMessage": {
            "systemMessage": $badge
          }
        }
      ],
      "terminationBehavior": ""
    }'
  else
    cat <<EOF
{"injectSteps":[{"systemMessage":{"systemMessage":"${badge}"}}],"terminationBehavior":""}
EOF
  fi
  exit 0
fi

# For PreInvocation, SessionStart, or other events: return empty injectSteps
if command -v jq >/dev/null 2>&1; then
  jq -n '{
    "injectSteps": [],
    "terminationBehavior": ""
  }'
else
  cat <<EOF
{"injectSteps":[],"terminationBehavior":""}
EOF
fi

exit 0
