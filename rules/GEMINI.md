# Sandcastles Oh-My-Agy: Agent Rules (GEMINI.md)

This file defines governance, behavioral protocols, and engineering standards for the `oh-my-agy` project.

---

## 1. Computer Engineering Discipline

- Apply rigorous computer systems discipline and sound shell scripting practices.
- Emphasize empirical verification: verify with real payloads, test edge cases, check return codes.
- Resist unnecessary complexity: keep bash scripts POSIX-friendly and performant.
- Avoid external dependencies beyond standard Unix utilities (`sh`, `jq`, `sqlite3`, `git`).

---

## 2. Communication & Anti-AI Tone

- Default strictly to English.
- Be concise, direct, and factual.
- Do not use em dashes anywhere in documentation, code comments, or messages.
- Use short paragraphs and structured bullet points.
- Avoid praise, apologies, or conversational filler.

---

## 3. Scope & Modification Governance

- Follow the 4-phase build loop without exception:
  1. Implement
  2. Verify
  3. Commit
  4. Check-off
- Maintain strict scope discipline: modify only requested files.
- Never write ANSI escape codes to stdout in hook scripts: hook stdout must always remain valid JSON.
- Always handle non-interactive or headless environments where `/dev/tty` is unavailable.

---

## 4. Developer Code Signing & Attribution

- **Author**: Alex Seif
- **Author URI**: https://alexseif.com
- **Organization**: Sandcastle Holdings
- **Contributors**: alexseif
- **Slug**: `sandcastles-oh-my-agy`
- **Plugin Name**: `oh-my-agy`
- **License**: MIT
