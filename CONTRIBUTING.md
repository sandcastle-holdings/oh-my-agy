# Contributing to oh-my-agy

Thank you for your interest in contributing to `oh-my-agy`.

This project enhances Antigravity sessions with contextual tab and window naming while maintaining zero viewport interference and zero token overhead.

---

## Architectural Principles

Every contribution must honor these core engineering requirements:

1. **Zero Viewport Interference**: Never output printable text, badges, or terminal cursor sequences to the viewport.
2. **Strict Pipe Separation**: OSC 0 title escape sequences are written exclusively to `/dev/tty`. Standard output (`stdout`) must strictly contain valid JSON for the Antigravity hook runner.
3. **Zero Token Ingestion**: Hook events must return empty `injectSteps: []` so that model conversation trajectories are not polluted.
4. **Minimal External Dependencies**: Rely strictly on standard Unix tools (`sh`, `jq`, `sqlite3`, `git`). Avoid adding runtimes like Node.js or Python.
5. **Headless Safety**: Scripts must degrade gracefully when `/dev/tty` is missing or unwritable (such as in CI runners or automated scripts).

---

## Development Setup

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/<your-username>/oh-my-agy.git
   cd oh-my-agy
   ```

2. Link to local Antigravity configuration for live testing:
   ```bash
   mkdir -p ~/.gemini/config/plugins
   ln -s "$(pwd)" ~/.gemini/config/plugins/oh-my-agy
   ```

3. Validate the plugin structure:
   ```bash
   agy plugin validate . --strict
   ```

---

## Testing

Run the automated test runner before opening a pull request:

```bash
chmod +x tests/test_hook.sh scripts/title_and_badge.sh
./tests/test_hook.sh
```

All tests must pass. If you introduce new features or handle new lifecycle events, add corresponding test cases to `tests/test_hook.sh`.

---

## Submitting Pull Requests

1. Create a dedicated branch for your change (`git checkout -b feature/my-feature`).
2. Make atomic, focused commits with descriptive messages.
3. Verify test coverage and strict plugin validation.
4. Submit your pull request against the `main` branch using the provided template.
