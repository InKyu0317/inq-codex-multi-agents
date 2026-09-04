# Specification: model-profiles

## Goal

Provide explicit `openai` and `claude` profiles that switch the Main Codex model and all five lifecycle-agent models together.

## Problem

Changing only the Main model leaves subagents on a different provider and creates an inconsistent lifecycle team. Manual edits across six configuration locations are error-prone.

## Scope

- Add source-controlled, credential-free profile definitions.
- Add a PowerShell profile switcher for a personal Codex home.
- Install the switcher and its definitions through the existing Windows installer.
- Back up affected files before a switch and restore them if a write fails.
- Document usage and add smoke coverage.

## Non-goals

- No quota monitoring, automatic switching, service, shim, daemon, or provider failover.
- No API key storage or OpenCodex provider configuration.
- No migration of already-running Main or subagent tasks.

## Functional requirements

- `openai` restores the existing Terra/Luna lifecycle allocation.
- `claude` sets Main and all lifecycle roles to `anthropic-apikey/claude-sonnet-5`.
- The switcher preserves unrelated Codex configuration.
- The switcher can report the active profile without writing files.

## Non-functional requirements

- Operate only beneath the selected personal Codex home.
- Reject unsafe profile names and incomplete or malformed profile definitions.
- Never print or persist credential values.

## Constraints

- Use no external PowerShell modules.
- Keep the feature manual and reversible.

## Acceptance criteria

- A single switch command updates Main plus all five roles.
- A pre-switch backup is created.
- `-Status` identifies the matching profile without writing.
- Installer smoke tests cover installation and both profile transitions.
