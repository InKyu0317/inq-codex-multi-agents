# Specification: frontend-ui-consistency

## Goal

Restore a dedicated frontend agent that preserves visual and interaction consistency across UI work.

## Problem

New UI can introduce controls, dimensions, or card layouts that conflict with nearby components and the existing design system.

## Scope

- Add `frontend-expert` to the managed agent set and both model profiles.
- Instruct it to reuse established components, interaction patterns, and layout dimensions.
- Keep installation, profile switching, documentation, and smoke tests aligned.

## Non-goals

- Create a design system, UI library, or runtime UI tooling.
- Change application UI code.

## Acceptance criteria

- The global installer deploys `frontend-expert.toml`.
- Both profiles switch its model with the other named agents.
- Its instructions require matching nearby component patterns and layout dimensions.
- The smoke test verifies installation and both profile switches.
