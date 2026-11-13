# Technical Specification: oh-my-agy

## 1. Architectural Overview

`oh-my-agy` operates as a native Antigravity plugin. It hooks into the agent execution loop at lifecycle boundaries (`SessionStart` and `PostInvocation`) to maintain terminal window titles and deliver visual status updates.

The plugin decouples user interface feedback from model context:
- **Terminal Titles**: Emitted via OSC 0 escape codes directly to `/dev/tty`.
- **Inline Badges**: Emitted via stdout as hook JSON responses using `metadata.user_markdown`.
- **Model Context**: Left completely unaffected by setting `systemMessage: ""`.

```
                    ┌───────────────────────────┐
                    │      Antigravity CLI      │
                    └─────────────┬─────────────┘
                                  │
                                  │ Hook Event (stdin JSON)
                                  ▼
                    ┌───────────────────────────┐
                    │ scripts/title_and_badge.sh │
                    └──────┬─────────────┬──────┘
                           │             │
        OSC 0 via /dev/tty │             │ JSON via stdout
                           ▼             ▼
       ┌─────────────────────┐       ┌──────────────────────┐
       │ Terminal Tab/Window │       │ Injected User Badge  │
       │  [repo:branch] Topic │       │ 📁 repo | 🌿 branch  │
       └─────────────────────┘       └──────────────────────┘
```

---

## 2. Hook Lifecycle Integration

### Configured Lifecycle Events

1. **`SessionStart`**:
   - Triggers once when a new conversation session initializes.
   - Sets the initial window title via `/dev/tty`.
   - Returns empty injectSteps (`{"injectSteps": [], "terminationBehavior": ""}`).

2. **`PreInvocation`**:
   - Triggers before each model invocation when the user submits a prompt.
   - Refreshes the terminal window title immediately so the title remains sticky across TUI redraws.
   - Returns empty injectSteps (`{"injectSteps": [], "terminationBehavior": ""}`) to ensure no pre-turn prompt pollution occurs.

3. **`PostInvocation`**:
   - Triggers immediately after assistant finishes responding.
   - Updates the terminal window title with the resolved topic title from the local SQLite summaries database.
   - Emits a styled visual footer divider directly to `/dev/tty`:
     `\n\033[90m── 📁 <folder> | 🌿 <branch> | 💬 <topic> | ⏰ <time> ──\033[0m\n\n`
   - Returns valid hook JSON with `injectSteps` containing the completion badge and `terminationBehavior: ""`.

### Hook Configuration (`hooks.json`)

```json
{
  "oh-my-agy": {
    "SessionStart": [
      {
        "type": "command",
        "command": "./scripts/title_and_badge.sh",
        "timeout": 10
      }
    ],
    "PreInvocation": [
      {
        "type": "command",
        "command": "./scripts/title_and_badge.sh",
        "timeout": 10
      }
    ],
    "PostInvocation": [
      {
        "type": "command",
        "command": "./scripts/title_and_badge.sh",
        "timeout": 10
      }
    ]
  }
}
```

---

## 3. Input & Output Data Contracts

### 3.1 Input Contract (stdin)

The hook receives JSON on stdin containing standard Antigravity session metadata:

```json
{
  "conversationId": "52cac4e1-6883-41ac-95cc-aeb74b5621bf",
  "workspacePaths": ["/home/alexseif/dev/sandcastles-oh-my-agy"],
  "cwd": "/home/alexseif/dev/sandcastles-oh-my-agy",
  "hookEventName": "PostInvocation",
  "modelName": "auto",
  "transcriptPath": "/path/to/transcript.jsonl",
  "artifactDirectoryPath": "/path/to/artifacts"
}
```

The script extracts:
- `conversationId`: Primary key for SQLite title lookup.
- `cwd`: Agent working directory, used to determine project name and git state.
- `workspacePaths`: Fallback directory if `cwd` is absent.
- `hookEventName`: Event name (`SessionStart`, `PreInvocation`, `PostInvocation`).

### 3.2 Output Contract (stdout)

#### For `PostInvocation`:
The script outputs the closing badge in `injectSteps`:

```json
{
  "injectSteps": [
    {
      "systemMessage": {
        "systemMessage": "📁 **sandcastles-oh-my-agy** | 🌿 `main` | 💬 *Agy CLI Chat Management Initiative* | ⏰ 09:20"
      }
    }
  ],
  "terminationBehavior": ""
}
```

#### For `SessionStart` and `PreInvocation`:
The script outputs empty injectSteps:

```json
{
  "injectSteps": [],
  "terminationBehavior": ""
}
```

---

## 4. User Configuration

Optional configuration can be placed in `~/.config/oh-my-agy/config.json`:

```json
{
  "show_footer": true,
  "show_title": true
}
```

- **`show_footer`** (boolean, default: `true`): Toggles the styled terminal footer divider printed to `/dev/tty` after each assistant turn.
- **`show_title`** (boolean, default: `true`): Toggles the OSC 0 escape sequence updating the window and tab title.

Key requirements:
- `systemMessage`: Must be an empty string (`""`) so the LLM receives no added tokens.
- `metadata.user_markdown`: The markdown string rendered inline in the CLI / IDE.
- No terminal escape sequences may be written to stdout. Writing ANSI escape codes to stdout invalidates the JSON payload.

---

## 4. Terminal Window and Tab Title Specification

### 4.1 Escape Code Standard

Terminal titles use the ANSI / xterm Operating System Command (OSC) sequence `0`:
- Sequence syntax: `\033]0;<title_string>\007`
- `\033` represents ASCII 27 (ESC).
- `]0;` designates setting both window title and icon/tab title.
- `\007` represents ASCII 7 (BEL), standard string terminator.

### 4.2 Formatted Title String

The title string follows this structure:
```text
[<folder>:<branch>] <topic>
```

Variations:
- Git repository with branch: `[sandcastles-oh-my-agy:main] PoC Architecture`
- Non-git workspace: `[my-project] Database Schema Refactor`
- Unindexed conversation: `[sandcastles-oh-my-agy:main] sandcastles-oh-my-agy @ 18:15`

### 4.3 Safe Device Handling

Hooks run as child processes. Writing directly to `/dev/tty` ensures the escape sequence reaches the user's terminal emulator rather than the agent process pipe:
- Verification check: `[ -w /dev/tty ]`
- Redirection: `printf '\033]0;%s\007' "$title" > /dev/tty 2>/dev/null || true`
- If `/dev/tty` is not accessible (e.g. CI environments, subagent sandboxes), the command exits cleanly without error.

---

## 5. Conversation Topic Resolution & Fallback

### 5.1 SQLite Query

The script queries the local Antigravity summaries database:
- Path: `~/.gemini/antigravity-cli/conversation_summaries.db`
- Query:
  ```sql
  SELECT title FROM conversation_summaries WHERE conversation_id = ? LIMIT 1;
  ```

### 5.2 Sanitization & Safety

- The `conversationId` is sanitized using POSIX pattern matching (`tr -cd 'a-zA-Z0-9_-'`) before running the query to prevent command or SQL injection.
- The database is opened read-only if supported by sqlite3 (`file:... ?mode=ro` or default read).

### 5.3 Fallback Hierarchy

When resolving the conversation topic:
1. Return `title` from SQLite database if present and non-empty.
2. If absent or empty, fall back to `<folder> @ <HH:MM>` (e.g. `sandcastles-oh-my-agy @ 18:15`).
3. If git branch is known, fall back to `<folder> (<branch>) @ <HH:MM>`.

---

## 6. Starship-Style Status Badge Format

The markdown status badge injected into the turn output adheres to the following layout:

```text
📁 **<folder>** | 🌿 `<branch>` | ⏰ <HH:MM>
```

When a human-readable topic is available:
```text
📁 **<folder>** | 🌿 `<branch>` | 💬 *<topic>* | ⏰ <HH:MM>
```

Design criteria:
- Standard UTF-8 emoji indicators for instant recognition.
- Bold project folder and code-formatted branch name.
- Italicized topic string when resolved from database.
- 24-hour timestamp indicating turn completion time.
