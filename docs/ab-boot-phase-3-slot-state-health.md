# Phase 3: Slot State And Health

## Goal

Teach the system which slot is running and whether the current boot is healthy.

## Scope

- Add current-slot detection.
- Add persistent slot metadata under `/var`.
- Add a boot-success health service.
- Add a command-line helper for inspecting slot state.

## Out Of Scope

- Installing updates into the inactive slot.
- Automatic rollback.
- Complex health policy beyond the first minimal success signal.

## Implementation Tasks

- Add an `abctl` helper or equivalent command.
- Detect the current slot from the mounted root partition label.
- Report the inactive slot.
- Store slot metadata under `/var/lib/ab-boot/` or a project-specific equivalent.
- Add a systemd oneshot service that marks the current boot successful.
- Decide whether to integrate with `systemd-bless-boot.service` and boot counting.

## Validation

- Boot slot A and confirm current slot reports `root-a`.
- Boot slot B and confirm current slot reports `root-b`.
- Confirm the inactive slot is reported correctly from each slot.
- Confirm the health service runs after required boot targets.
- Confirm successful boot state is persisted under `/var`.

## Deployable Gate

- Manual slot boot still works.
- Slot state can be inspected from either slot.
- A successful boot is recorded automatically.

## Risks

- Marking boot success too early can hide broken graphical or user-session startup.
- Marking boot success too late can cause false rollback in later phases.
- Slot state stored outside `/var` would be lost during root replacement.
