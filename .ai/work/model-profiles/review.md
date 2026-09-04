# Review: model-profiles

## Specification and acceptance-criteria compliance

PASS. The implementation supplies credential-free OpenAI and Claude profiles, switches Main plus all five lifecycle roles together, preserves unrelated configuration, creates backups, and provides a non-writing status command.

## Design compliance

PASS. JSON definitions remain data-only. The PowerShell switcher stages all changes, backs up affected files, and rolls back written files on a failure. The installer installs definitions and the switcher but does not activate either profile.

## Tests performed and results

- `tests/install-global.smoke.ps1` passed: temporary install, Claude transition, profile status, OpenAI restoration, backups, and reinstall.
- PowerShell parser validation passed for `switch-profile.ps1`.
- `git diff --check` passed.
- Repository scan found no Anthropic API-key-shaped content.
- Installed `~/.codex` verification reported `Active profile: openai` and the expected five OpenAI role mappings.

## Regression and compatibility risk

Existing tasks keep their current model. New Codex sessions are required before new Main tasks or subagents use a changed profile. The switcher is PowerShell-only; POSIX installation behavior is unchanged.

## Security concerns

Profile definitions must remain credential-free.

## Unresolved issues and technical debt

The switcher is intentionally manual and PowerShell-only. It does not monitor usage or provide automatic provider failover.

## Final outcome

Approved STANDARD implementation completed and installed locally.
