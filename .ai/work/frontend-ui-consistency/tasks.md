# Tasks: frontend-ui-consistency

## T001 — Add frontend agent and profile mappings

Status: DONE

Files:

- `.codex/agents/frontend-expert.toml`
- `profiles/openai.json`
- `profiles/claude.json`
- `switch-profile.ps1`

Dependencies:

- None

Acceptance criteria:

- The agent has explicit UI consistency guidance and both profiles define it.

## T002 — Align installer, documentation, and verification

Status: DONE

Files:

- `AGENTS.md`
- `install-global.ps1`
- `tests/install-global.smoke.ps1`
- `README.md`

Dependencies:

- T001

Acceptance criteria:

- Installation and model switching are documented and tested.
