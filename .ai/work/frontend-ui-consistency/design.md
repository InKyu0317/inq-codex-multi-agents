# Design: frontend-ui-consistency

## Architecture and components

Add one agent definition and one role entry to each existing profile. Extend the existing role lists in the profile switcher and smoke test.

## Module boundaries

`frontend-expert.toml` owns frontend implementation guidance. The existing installer copies all source agent TOML files; only its legacy-retirement list needs adjustment.

## Risks and compatibility

Existing installations may have an old frontend agent. The installer backs it up before replacing it, as it does for all managed agent files.
