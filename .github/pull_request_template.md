### Summary of Changes

Describe the proposed changes, the motivation behind them, and which issue or component they address.

### Verification Performed

- [ ] Ran automated test suite (`./tests/test_hook.sh`) with all tests passing
- [ ] Validated manifest via `agy plugin validate . --strict`
- [ ] Verified that hook output stdout remains valid JSON without escape codes
- [ ] Checked that OSC 0 output is strictly sent to `/dev/tty` only

### Checklist

- [ ] Code follows project conventions (POSIX-compliant shell, zero external dependencies beyond `jq`, `sqlite3`, `git`)
- [ ] No ANSI control characters or markdown badges are printed to the terminal viewport
- [ ] Documentation and specifications updated if behavior changed
