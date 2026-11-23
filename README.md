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
├── assets/
│   └── logo.svg              # Brand icon
├── rules/
│   ├── AGENTS.md             # Agent governance rules
│   └── GEMINI.md -> AGENTS.md
├── scripts/
│   └── title_and_badge.sh    # Main title generator
├── tests/
│   └── test_hook.sh          # Automated test suite
├── OBJECTIVE.md              # Project objective and roadmap
├── SPEC.md                   # Technical specification
└── README.md                 # This file
```

---

## Prerequisites

- Operating System: Linux or macOS
- Dependencies: `sh`, `jq`, `git`, `sqlite3`

All dependencies are standard utilities available on modern Unix-like systems.

---

## Installation & Enablement

### 1. Global Installation (Recommended)
Clone directly into your global Antigravity plugins directory:

```bash
mkdir -p ~/.gemini/config/plugins
git clone https://github.com/sandcastle-holdings/oh-my-agy.git ~/.gemini/config/plugins/oh-my-agy
```

Antigravity automatically discovers and activates the plugin upon session launch.

### 2. Local Directory Install via agy CLI
Alternatively, clone the repository locally and install via the CLI:

```bash
git clone https://github.com/sandcastle-holdings/oh-my-agy.git
agy plugin install ./oh-my-agy
```

### 3. Local Workspace Installation
To load `oh-my-agy` for a single project workspace:

```bash
mkdir -p .agents/plugins
ln -s /path/to/oh-my-agy .agents/plugins/oh-my-agy
```

### 4. Custom Marketplace Catalog
This repository maintains a self-contained `marketplace.json` catalog entry, allowing organizations and teams to reference or mirror it in custom marketplace configurations.

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
{"injectSteps":[],"terminationBehavior":""}
```
*Note*: The OSC 0 window title sequence is written directly to `/dev/tty`.

### 2. Test PostInvocation with Database Topic

```bash
echo '{
  "conversationId": "test-uuid-001",
  "cwd": "/home/alexseif/dev/sandcastles-oh-my-agy",
  "hookEventName": "PostInvocation"
}' | ./scripts/title_and_badge.sh
```

Expected output (stdout):
```json
{"injectSteps":[],"terminationBehavior":""}
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
