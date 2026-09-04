# Implementation Plan: model-profiles

## Phases and sequencing

1. Add data-only OpenAI and Claude profile definitions.
2. Implement and validate the PowerShell switcher.
3. Extend the Windows installer to copy managed profile files.
4. Extend smoke tests for installed switching, rollback-safe backups, and status.
5. Document manual usage and validate repository/install behavior.

## Affected modules and files

- `profiles/*.json`
- `switch-profile.ps1`
- `install-global.ps1`
- `tests/install-global.smoke.ps1`
- `README.md`

## Migration strategy

The first installation adds managed profile files without selecting a profile. Existing global settings are unchanged until the user invokes the switcher.

## Testing strategy

- Run the PowerShell smoke test in a temporary Codex home.
- Exercise `openai`, `claude`, and `-Status` paths.
- Check the repository for API-key-shaped content and run `git diff --check`.

## Rollback strategy

Every switch writes a timestamped backup below `~/.codex/backups/inq-codex-model-profiles/`. Re-run the opposite profile or restore the backed-up files manually.
