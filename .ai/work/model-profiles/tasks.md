# Tasks: model-profiles

## Status values

`TODO` · `IN_PROGRESS` · `DONE` · `BLOCKED`

## T001 — Add credential-free profile definitions

Status: DONE

Files:

- `profiles/openai.json`
- `profiles/claude.json`

Dependencies:

- None

Acceptance criteria:

- Definitions cover Main, defaults, and five lifecycle roles.

## T002 — Implement manual profile switcher

Status: DONE

Files:

- `switch-profile.ps1`

Dependencies:

- T001

Acceptance criteria:

- Validates, backs up, stages, applies, rolls back, and reports status.

## T003 — Install and document profiles

Status: DONE

Files:

- `install-global.ps1`
- `README.md`

Dependencies:

- T002

Acceptance criteria:

- Windows install copies the switcher and definitions without activating a profile.

## T004 — Verify profile transitions

Status: DONE

Files:

- `tests/install-global.smoke.ps1`
- `.ai/work/model-profiles/review.md`

Dependencies:

- T001
- T002
- T003

Acceptance criteria:

- Temporary-home smoke test verifies both profiles and status.
