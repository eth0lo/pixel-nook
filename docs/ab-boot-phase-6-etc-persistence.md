# Phase 6: `/etc` Persistence Hardening

## Goal

Harden the minimal `/etc` persistence introduced earlier so root slots can become read-only and safely replaceable.

## Scope

- Review and finalize the `/etc` persistence strategy.
- Expand or reduce the persisted file set based on observed first-boot and desktop behavior.
- Avoid carrying unmanaged stale configuration across OS updates.
- Validate persistence when switching slots and installing updates.
- Enable read-only root slots only after required `/etc` writes are handled.

## Out Of Scope

- General-purpose persistence of every `/etc` change.
- User data under `/home`, which is already shared.
- Application state under `/var`, which is already shared.

## Implementation Tasks

- Audit which `/etc` files change during first boot, user creation, networking, and normal desktop use.
- Confirm the existing minimum account persistence covers `passwd`, `shadow`, `group`, `gshadow`, `subuid`, and `subgid` as needed.
- Confirm `machine-id` behavior matches the project contract.
- Decide whether to use an OverlayFS approach or targeted import/export of selected files.
- Ensure image-provided system users and groups remain authoritative after updates.
- Ensure local users and groups survive slot replacement.
- Add permissions checks for persisted sensitive files.
- Switch boot entries from `rw` to `ro` only after validation proves first-user creation and login still work.

## Validation

- Create the first user on slot A.
- Switch to slot B and confirm the user can log in.
- Install an update to the inactive slot and confirm the user can still log in after switching.
- Confirm `machine-id` behavior matches the contract from Phase 0.
- Confirm image updates can add or modify system users and groups without being overridden by stale persisted files.
- Confirm unmanaged `/etc` changes do not accidentally become permanent unless explicitly supported.

## Deployable Gate

- Required local identity state survives A/B slot switches and updates.
- OS-owned `/etc` defaults from the active slot remain authoritative.
- Sensitive persisted files have correct ownership and permissions.
- Root slots can be mounted read-only without breaking GNOME Initial Setup or login.

## Risks

- Persisting too much of `/etc` can block OS updates from taking effect.
- Persisting too little of `/etc` can break login, identity, or first-boot behavior.
- Merging account databases incorrectly can create UID/GID conflicts.
