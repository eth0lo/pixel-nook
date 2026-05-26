# Phase 7: Documentation And Test Matrix

## Goal

Make the A/B boot system maintainable, testable, and recoverable.

## Scope

- Document the final disk layout.
- Document build, boot, update, rollback, and recovery flows.
- Add a repeatable manual test matrix.
- Add automated checks where practical.

## Out Of Scope

- New A/B boot features.
- Remote update service integration.
- Production release automation, unless separately planned.

## Implementation Tasks

- Update `README.md` with the A/B image behavior.
- Document the partition table and labels.
- Document how to boot each slot manually.
- Document how to inspect slot state.
- Document how to stage an update.
- Document rollback behavior.
- Document recovery steps from firmware or QEMU.
- Add test notes for fresh image, slot switch, update success, update failure, and persistence.

## Validation

- A fresh checkout can follow the documented build instructions.
- A tester can boot slot A and slot B using the docs.
- A tester can stage an update using the docs.
- A tester can simulate failed update rollback using the docs.
- Test results can be compared against the documented expected state.

## Deployable Gate

- Documentation matches implemented behavior.
- The test matrix covers all A/B critical paths.
- Known limitations and recovery paths are documented.

## Risks

- Undocumented recovery flows make failed updates harder to diagnose.
- Manual-only validation can miss regressions as the image evolves.
- Docs can drift from mkosi and bootloader implementation details.
