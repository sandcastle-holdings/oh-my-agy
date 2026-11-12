# Objective: oh-my-agy

## Vision

`oh-my-agy` is a lightweight statusline and terminal enhancement plugin for the Antigravity CLI and IDE ecosystem, inspired by Starship and Oh My Zsh. It delivers ambient context, automatic terminal tab/window naming, and rich status badges directly into Antigravity sessions without polluting model context.

## Core Problem

Developers running concurrent Antigravity sessions across multiple repositories face context fragmentation:
- Terminal window and tab titles remain static or generic, making navigation cumbersome across multiple tmux windows or terminal tabs.
- Agent sessions lack immediate, at-a-glance visual indicators of repository, active git branch, time of turn completion, and active conversation topic.
- Injected system prompts frequently clutter model context windows, consuming tokens unnecessarily.

## Strategic Objectives

1. **Ambient Terminal Identification**:
   - Emit standard Operating System Command (OSC 0) escape sequences to dynamically update terminal window and tab titles.
   - Reflect current project directory, active git branch, and conversation title.

2. **Inline Starship-Style Badges**:
   - Inject compact, visually clean markdown badges on session start and after invocations.
   - Use `metadata.user_markdown` with empty `systemMessage` text so badges render inline for the user while consuming zero LLM input tokens.

3. **Resilient Context Resolution**:
   - Query Antigravity's local SQLite database (`conversation_summaries.db`) for human-readable conversation titles.
   - Provide instant, graceful fallbacks to folder name, git branch, and timestamp when a conversation is new or unindexed.

4. **Zero Overhead & Minimal Touch**:
   - Rely strictly on standard Unix tools (`sh`, `jq`, `sqlite3`, `git`).
   - Execute in milliseconds without external runtime dependencies.
   - Fail silently and safely if standard output or `/dev/tty` is redirected, unattached, or headless.

## Phased Roadmap

### Phase 1: Proof of Concept (Current Phase)
- Implement `plugin.json` manifest and `hooks.json` configuration.
- Implement `scripts/title_and_badge.sh` handling stdin JSON payloads.
- Support OSC 0 terminal window/tab title updates via `/dev/tty`.
- Support `metadata.user_markdown` status badge injection.
- Support SQLite database lookup with fallback formatting.
- Implement comprehensive automated test runner `tests/test_hook.sh`.

### Phase 2: Configurable Themes and Diagnostics
- Add user configuration support for customizable badge formats and icons.
- Add git status dirty flags (staged, uncommitted, untracked counts).
- Display execution latency and turn duration metrics.

### Phase 3: Swarm and Agent Multi-Tasking
- Detect subagent and swarm sessions.
- Provide distinct role indicators for background workers and coordinators.
- Optional terminal desktop notifications (OSC 9 / OSC 777) upon long-running task completion.
