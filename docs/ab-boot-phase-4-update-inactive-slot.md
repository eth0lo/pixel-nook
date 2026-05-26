# Phase 4: Update Inactive Slot

## Goal

Install a new OS version into the inactive root slot without modifying the running slot.

## Scope

- Define and consume an update artifact.
- Detect the active and inactive slots.
- Replace the inactive slot contents.
- Prepare the inactive slot as the pending next boot.
- Preserve shared `/var` and `/home`.

## Out Of Scope

- Automatic rollback on failed boot.
- Delta updates.
- Remote update distribution.
- Full production signing policy, unless required before testing update artifacts.

## Implementation Tasks

- Define the first update artifact format.
- Add installer safety checks for partition labels and mount state.
- Format or otherwise clean the inactive root partition before deployment.
- Deploy the new root filesystem into the inactive slot.
- Update or create the boot entry for the inactive slot.
- Mark the inactive slot as pending for next boot.
- Refuse to update if the inactive slot cannot be identified safely.

## Validation

- Boot from slot A.
- Install an update into slot B.
- Reboot into slot B.
- Confirm slot B runs the updated OS contents.
- Confirm slot A remains bootable as the previous slot.
- Repeat the flow from slot B back to slot A.
- Confirm `/var` and `/home` are not reformatted or replaced.

## Deployable Gate

- A staged update can switch from A to B.
- A staged update can switch from B to A.
- The previous slot remains available for manual recovery.

## Risks

- A bad artifact can produce an unbootable inactive slot.
- Accidentally formatting the active slot would destroy the running system.
- Shared `/var` schema changes can make downgrade or rollback unsafe.
