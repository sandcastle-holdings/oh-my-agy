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

# Emit OSC 0 escape sequence to tty if writable
# Support OH_MY_AGY_TTY override for testing environments
tty_device="${OH_MY_AGY_TTY:-/dev/tty}"
if [ -w "$tty_device" ]; then
  printf '\033]0;%s\007' "$window_title" > "$tty_device" 2>/dev/null || true
fi

# Build Starship-style status badge
branch_badge=""
if [ -n "$git_branch" ]; then
  branch_badge=" | 🌿 \`${git_branch}\`"
fi

topic_badge=""
if [ -n "$topic" ]; then
  topic_badge=" | 💬 *${topic}*"
fi

badge="📁 **${folder_name}**${branch_badge}${topic_badge} | ⏰ ${current_time}"

# Output valid hook JSON to stdout
if command -v jq >/dev/null 2>&1; then
  jq -n --arg badge "$badge" '{
    "injectSteps": [
      {
        "systemMessage": {
          "systemMessage": "",
          "metadata": {
            "user_markdown": $badge
          }
        }
      }
    ]
  }'
else
  cat <<EOF
{"injectSteps":[{"systemMessage":{"systemMessage":"","metadata":{"user_markdown":"${badge}"}}}]}
EOF
fi

exit 0
