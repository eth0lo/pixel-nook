# Phase 2: Manual Slot Boot

## Goal

Make both `root-a` and `root-b` independently bootable by manual boot entry selection.

## Scope

- Populate `root-b` with a bootable OS root.
- Generate or install one boot entry for `root-a` and one boot entry for `root-b`.
- Keep `/var` and `/home` shared between both slots.
- Add a simple slot identity marker to each root slot for validation.
- Add the minimum `/etc` account persistence required for first-user creation and login to work across slots.

## Out Of Scope

- Automatic slot switching.
- Update installation.
- Rollback.
- Full generalized `/etc` persistence beyond the minimum account and identity files required for slot switching.

## Implementation Tasks

- Copy the built OS root into both `root-a` and `root-b` during image creation.
- Create boot entry A with `root=PARTLABEL=root-a rw` unless read-only root support is completed in this phase.
- Create boot entry B with `root=PARTLABEL=root-b rw` unless read-only root support is completed in this phase.
- Add a slot marker to each slot, such as `/usr/lib/ab-boot/slot`.
- Persist the first-user account databases needed by GNOME Initial Setup, at minimum `passwd`, `shadow`, `group`, `gshadow`, `subuid`, and `subgid` if those files are changed.
- Persist `machine-id` if the Phase 0 contract requires stable identity across slots.
- Store persisted `/etc` state on `/var`, not inside either root slot.
- Document how to select each boot entry from firmware or bootloader UI.

## Validation

- Boot slot A manually and confirm the slot marker reports `root-a`.
- Boot slot B manually and confirm the slot marker reports `root-b`.
- Confirm both slots reach the same desktop flow.
- Create the first user on slot A, boot slot B, and confirm that user can still log in.
- Confirm `/var` and `/home` contents are visible from both slots.
- Confirm changing data under `/home` from slot A is visible from slot B.

## Deployable Gate

- Both slots are manually bootable.
- First-user creation and login work after switching slots.
- Slot switching does not require rebuilding the image.
- Shared writable state survives manual slot switches.

## Risks

- Boot entries may depend on firmware NVRAM state instead of being discoverable from the ESP.
- Two slots can drift immediately if runtime writes land inside `/etc` or other root-owned paths.
- Shared `/var` can expose incompatibilities when booting different OS versions in later phases.
- An incomplete `/etc` persistence mechanism can make one slot boot but prevent login on the other slot.
