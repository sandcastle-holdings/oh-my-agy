# oh-my-agy (Tab-Only Mode)

> Dynamic terminal tab and window naming for Google Antigravity with zero viewport interference.

Engineered by Alex Seif and Sandcastle Holdings.

---

## Overview

`oh-my-agy` is a native plugin for the Google Antigravity CLI and IDE operating in **Tab-Only Mode**. It enriches developer sessions with contextual terminal tab and window titles while maintaining absolute viewport purity:

- **Dynamic Terminal Titles**: Sets terminal window and tab titles via standard OSC 0 escape codes, formatted as `[<folder>:<branch>] <topic>`.
- **Zero Viewport Interference**: Never prints text, badges, or ANSI control sequences to the terminal viewport, eliminating cursor jitter and terminal desynchronization.
- **Zero Token Overhead**: Returns empty `injectSteps: []` across all lifecycle events, preserving conversation trajectory and token budgets.
- **SQLite Topic Lookup**: Reads Antigravity's local session summary database to retrieve human-readable conversation titles, with automatic fallbacks for new conversations.

---

## Architecture

The plugin hooks into Antigravity lifecycle events through `hooks.json`:

- `SessionStart`: Sets the initial terminal window and tab title via `/dev/tty`.
- `PreInvocation`: Refreshes the window title on prompt submission so it remains sticky across TUI redraws.
- `PostInvocation`: Refreshes the window title after the model completes using the newly indexed conversation topic from SQLite.

OSC 0 escape sequences are directed straight to `/dev/tty` so they never corrupt Antigravity's standard JSON communication pipes. Hook responses are returned as strict empty JSON payloads to `stdout`.

```text
Antigravity Runtime
       │
       ├─► stdin (JSON context: cwd, conversationId, hookEventName, etc.)
       ▼
scripts/title_and_badge.sh
       │
       ├─► /dev/tty: OSC 0 escape sequence only (\033]0;[folder:branch] topic\007)
       ▼
   stdout: {"injectSteps": [], "terminationBehavior": ""} (zero trajectory pollution)
```

---

## Configuration

Custom settings can be defined in `~/.config/oh-my-agy/config.json`:

```json
{
  "show_title": true
}
```

- `show_title`: Toggles the OSC 0 escape sequence updating the window and tab title (default: `true`).

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
