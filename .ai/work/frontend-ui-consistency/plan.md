# Implementation Plan: frontend-ui-consistency

## Phases and sequencing

1. Add the agent prompt and model-profile entries.
2. Include the role in switching, installation, test, and documentation paths.
3. Run the installer smoke test and verify global deployment.

## Testing strategy

Run `tests/install-global.smoke.ps1` and check both profiles update the frontend agent.
