# oh-my-agy

> Delightful terminal statuslines, dynamic window naming, and ambient context badges for Google Antigravity.

Engineered by Alex Seif and Sandcastle Holdings.

---

## Overview

`oh-my-agy` is a native plugin for the Google Antigravity CLI and IDE. Inspired by Starship and Oh My Zsh, it enriches developer sessions with contextual terminal enhancements while preserving token budgets:

- **Dynamic Terminal Titles**: Sets your terminal window and tab title via OSC 0 escape codes, formatting it as `[<folder>:<branch>] <topic>`.
- **Inline Status Badges**: Injects a clean status badge (`📁 folder | 🌿 branch | ⏰ time`) at session startup and turn completion.
- **Zero Token Overhead**: Uses Antigravity's `metadata.user_markdown` hook feature with empty system prompts, ensuring the model's context window remains untouched.
- **SQLite Topic Lookup**: Reads Antigravity's local session summary database to retrieve human-readable conversation titles, with automatic fallbacks for new conversations.

---

## Architecture

The plugin hooks into Antigravity lifecycle events through `hooks.json`:

- `SessionStart`: Runs when a conversation starts, establishing initial window title and badge.
- `PreInvocation`: Runs before each model turn, ensuring the window title remains sticky across TUI redraws and showing an updated badge.
- `PostInvocation`: Runs after each model turn finishes, updating the terminal title with the conversation title from the local SQLite database.

Escape sequences for window titles are directed straight to `/dev/tty` so they never corrupt Antigravity's standard JSON communication pipes. Hook results are returned as strict JSON payloads to `stdout`.

```text
Antigravity Runtime
       │
       ├─► stdin (JSON context: cwd, conversationId, hookEventName, etc.)
       ▼
scripts/title_and_badge.sh
       │
       ├─► /dev/tty: OSC 0 escape sequence (\033]0;[folder:branch] topic\007)
       ▼
   stdout: SessionStart/PreInvocation -> {"injectSteps": [{"systemMessage": {"systemMessage": "..."}}]}
           PostInvocation             -> {"injectSteps": [], "terminationBehavior": ""}
```

---

## Directory Structure

```text
sandcastles-oh-my-agy/
├── plugin.json               # Plugin manifest
├── hooks.json                # Lifecycle hook configuration
├── scripts/
│   └── title_and_badge.sh    # Main title and badge generator
├── tests/
│   └── test_hook.sh          # Automated test suite
├── OBJECTIVE.md              # Project objective and roadmap
├── SPEC.md                   # Technical specification
├── GEMINI.md                 # Agent rules and governance
├── AGENTS.md -> GEMINI.md    # Standard symlink
└── README.md                 # This file
```

---

## Prerequisites

- Operating System: Linux or macOS
- Dependencies: `sh`, `jq`, `git`, `sqlite3`

All dependencies are standard utilities available on modern Unix-like systems.

---

## Installation & Enablement

### Local Workspace Installation
To load `oh-my-agy` into your project:

```bash
# In your project root
mkdir -p .agents/plugins
ln -s /home/alexseif/dev/sandcastles-oh-my-agy .agents/plugins/oh-my-agy
```

### Global Installation
To enable `oh-my-agy` globally across all Antigravity CLI sessions:

```bash
mkdir -p ~/.gemini/config/plugins
ln -s /home/alexseif/dev/sandcastles-oh-my-agy ~/.gemini/config/plugins/oh-my-agy
```

---

## Manual Testing Guide

You can run the script manually to test its behavior with simulated Antigravity payloads:

### 1. Test SessionStart (New Session)

```bash
echo '{
  "conversationId": "test-uuid-001",
  "cwd": "/home/alexseif/dev/sandcastles-oh-my-agy",
  "hookEventName": "SessionStart"
}' | ./scripts/title_and_badge.sh
```

Expected output (stdout):
```json
{
  "injectSteps": [
    {
      "systemMessage": {
        "systemMessage": "",
        "metadata": {
          "user_markdown": "📁 **sandcastles-oh-my-agy** | 🌿 `main` | ⏰ 18:20"
        }
      }
    }
  ]
}
```

### 2. Test PostInvocation with Database Topic

```bash
echo '{
  "conversationId": "ecb50299-ff21-43f1-9353-e09135ffb8be",
  "cwd": "/home/alexseif/dev/sandcastles-oh-my-agy",
  "hookEventName": "PostInvocation"
}' | ./scripts/title_and_badge.sh
```

Expected output (stdout):
```json
{
  "injectSteps": [
    {
      "systemMessage": {
        "systemMessage": "",
        "metadata": {
          "user_markdown": "📁 **sandcastles-oh-my-agy** | 🌿 `main` | 💬 *Agy CLI Chat Management Initiative* | ⏰ 18:20"
        }
      }
    }
  ]
}
```

### 3. Automated Test Suite

Run the automated test suite directly:

```bash
./tests/test_hook.sh
```

---

## License & Attribution

- **Author**: Alex Seif
- **Author URI**: https://alexseif.com
- **Organization**: Sandcastle Holdings
- **Contributors**: alexseif
- **License**: MIT
