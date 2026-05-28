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

## Constraints

- Keep `root-a` as the default boot entry.
- Keep `root-b` as a manual alternate entry selected through the visible `systemd-boot` menu.
- Keep shared kernel and initrd payloads on the ESP for both entries in this phase.
- Keep both root slots mounted read-write in this phase.
- Keep both slots identical except for the slot-local `/usr/lib/ab-boot/slot` marker.
- Guarantee cross-slot continuity only for `/home`, `/var`, and the allowlisted identity files bound onto `/etc`.
- Keep the `/etc` persistence scope limited to `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/subuid`, `/etc/subgid`, and `/etc/machine-id`.
- Pre-populate `/var/lib/ab-boot/etc/` during image build and treat it as canonical from first boot onward.
- Use individual `fstab` bind mounts for the allowlisted `/etc` files instead of generalized `/etc` overlay or sync logic.
- Support the shipped initialization flow where first-user creation happens on the default `root-a` boot path.

Diagnostic-only note: booting a pristine image into `root-b` first can still be tested, but it is not part of the supported Phase 2 acceptance path.

## Implementation Tasks

- Copy the built OS root into both `root-a` and `root-b` during image creation.
- Keep boot entry A as the default boot path with `root=PARTLABEL=root-a rw`.
- Add a manual boot entry B with `root=PARTLABEL=root-b rw`.
- Keep the shared ESP payloads for both entries aligned and derive the `root-b` entry from the generated `root-a` entry.
- Add a slot marker to each slot, such as `/usr/lib/ab-boot/slot`.
- Persist the first-user account databases needed by GNOME Initial Setup: `passwd`, `shadow`, `group`, `gshadow`, `subuid`, and `subgid`.
- Persist `machine-id` so identity remains stable across slot switches.
- Store persisted `/etc` state under `/var/lib/ab-boot/etc/`, not inside either root slot.
- Pre-populate the allowlisted persisted files during image build.
- Bind-mount the allowlisted files individually onto `/etc` at boot.
- Document slot selection through the `systemd-boot` UI.

## Validation

- Boot the default `root-a` entry and complete GNOME Initial Setup.
- Confirm the `systemd-boot` menu exposes both `root-a` and `root-b` entries and defaults to `root-a` after a short timeout.
- Boot `root-b` manually and confirm the slot marker reports `root-b`.
- Confirm both slots reach the same login or desktop flow after initialization on `root-a`.
- Confirm the allowlisted `/etc` files are bind-mounted from `/var/lib/ab-boot/etc/`.
- Confirm the user created on `root-a` can log in on `root-b`.
- Confirm `/var` and `/home` contents are visible from both slots.
- Confirm changing data under `/home` from `root-a` is visible from `root-b`.
- Boot back into `root-a` and confirm login and shared state still work.

## Deployable Gate

- Both slots are manually bootable.
- First-user creation and login work after switching slots.
- Slot switching does not require rebuilding the image.
- Shared writable state survives manual slot switches.
- The visible boot menu and slot markers make manual selection and verification unambiguous.
- Non-allowlisted slot-local root changes are not documented as cross-slot guarantees.

## Risks

- Boot entries may depend on firmware NVRAM state instead of being discoverable from the ESP.
- Two slots can drift immediately if runtime writes land inside `/etc` or other root-owned paths.
- Shared `/var` can expose incompatibilities when booting different OS versions in later phases.
- An incomplete `/etc` persistence mechanism can make one slot boot but prevent login on the other slot.
- Shared ESP payloads are a temporary constraint that will need to be revisited once slots can carry different OS versions.
