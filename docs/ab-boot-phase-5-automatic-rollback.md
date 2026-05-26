# Phase 5: Automatic Rollback

## Goal

Automatically return to the previous good slot when a pending update fails.

## Scope

- Add boot attempt tracking for pending slots.
- Integrate boot success with the selected bootloader strategy.
- Mark failed pending slots as bad.
- Restore the previous good slot automatically.
- Record rollback reason and status.

## Out Of Scope

- Remote telemetry.
- Complex multi-version history beyond A/B.
- Repairing broken update artifacts.

## Implementation Tasks

- Configure pending slot boot attempts.
- Mark a pending slot good only after the health service succeeds.
- Mark a pending slot bad when boot attempts are exhausted or health fails.
- Select the previous good slot after failure.
- Add `abctl` commands or status output for rollback state.
- Store rollback records under `/var/lib/ab-boot/` or a project-specific equivalent.

## Validation

- Install a good update and confirm it remains selected after health success.
- Install a deliberately broken update and confirm the system returns to the previous slot.
- Confirm rollback reason is recorded.
- Confirm manual boot selection remains possible after rollback.
- Confirm repeated failed updates do not corrupt slot metadata.

## Deployable Gate

- Failed pending boot returns to previous good slot without manual intervention.
- Successful pending boot becomes the new good slot.
- Rollback state is inspectable after recovery.

## Risks

- Incorrect boot counting can loop forever on a broken slot.
- Incorrect success marking can bless a broken slot.
- Firmware-specific boot behavior can differ from QEMU testing.
