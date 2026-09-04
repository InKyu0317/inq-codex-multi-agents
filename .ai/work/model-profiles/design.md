# Design: model-profiles

## Architecture and components

- `profiles/openai.json` and `profiles/claude.json` declare the Main, unnamed-subagent, and named-role model settings.
- `switch-profile.ps1` validates a selected profile, stages all target contents, backs up originals, and applies the staged configuration.
- `install-global.ps1` copies the managed definitions and switcher to the selected Codex home.

## Module boundaries

- Profiles hold data only and never credentials.
- The switcher owns profile validation, TOML line replacement, backups, rollback, and status reporting.
- The installer owns source-to-home installation only; it never selects a profile.

## Data flow

```text
profile JSON → staged config.toml + five agent TOMLs → backup → write → active-profile.json
```

## Alternatives considered

- Changing only `config.toml`: rejected because named lifecycle roles retain their own models.
- Automatic quota-triggered switching: rejected because it conflicts with the project's manual-backup policy and changes provider behavior during work.
- Storing API keys per profile: rejected because secrets remain environment-managed by OpenCodex.

## Risks and compatibility

- Existing tasks retain their existing model; only newly created tasks load the new profile.
- A process restart may be required for the app to reload global settings.
- The switcher is PowerShell-only; the existing POSIX installer remains unchanged.
