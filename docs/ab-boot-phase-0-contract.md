# Phase 0: A/B Boot Contract

## Goal

Define the A/B boot behavior before changing the image layout or boot flow.

## Scope

- Document the slot model: `root-a` and `root-b` are replaceable OS roots.
- Document shared writable state: `/var` and `/home` are outside the root slots.
- Choose the bootloader integration approach, preferably `systemd-boot` and Boot Loader Specification entries.
- Define how a slot becomes pending, good, bad, or rollback-eligible.
- Define the minimum health signal required to mark a boot successful.
- Define the expected update artifact format.

## Out Of Scope

- Partition layout changes.
- Bootloader implementation.
- Update installation.
- `/etc` persistence implementation.

## Implementation Tasks

- Add an A/B boot design note to the project documentation.
- Record the selected bootloader strategy.
- Record the slot state machine.
- Record which paths are shared and which paths belong to each root slot.
- Record assumptions about fresh images versus existing installed disks.

## Validation

- The documented contract explains how the system boots initially.
- The documented contract explains how updates are staged.
- The documented contract explains how rollback is triggered.
- The documented contract explicitly states that shared state is not part of either root slot.

## Deployable Gate

- Documentation-only change is merged.
- No generated image behavior changes.

## Risks

- A vague contract can lead to incompatible implementation choices in later phases.
- Choosing an update artifact too late can force rework in the slot installer.
