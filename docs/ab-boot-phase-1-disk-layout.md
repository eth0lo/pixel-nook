# Phase 1: A/B Disk Layout

## Goal

Produce an A/B-compatible disk image that still boots only from `root-a`.

## Scope

- Add a stable partition layout with an ESP, `root-a`, `root-b`, `/var`, and `/home`.
- Copy the current OS root into `root-a`.
- Create `root-b` as an inactive slot.
- Mount shared `/var` and `/home` using stable partition labels.
- Configure the kernel command line to boot `root-a` read-write.

## Out Of Scope

- Booting `root-b`.
- Automatic slot selection.
- Update installation.
- Rollback.
- `/etc` persistence objects or merge behavior.
- Read-only root enforcement.

## Implementation Tasks

- Add `mkosi/mkosi.repart/` partition definitions.
- Define a fixed-size or bounded-size `root-a` partition.
- Define a matching `root-b` partition.
- Define writable `/var` and `/home` partitions.
- Add an image `fstab` that mounts `/var` and `/home` by `PARTLABEL`.
- Set the default kernel command line to `root=PARTLABEL=root-a rw`.
- Keep `root-a` writable in this phase so GNOME Initial Setup can create the first user and write account databases under `/etc`.
- Confirm the generated disk still uses UEFI boot.

## Validation

- Build the image with the containerized mkosi workflow.
- Boot the image in QEMU.
- Confirm `/` is mounted from `root-a`.
- Confirm `/var` is mounted from the `var` partition.
- Confirm `/home` is mounted from the `home` partition.
- Confirm `root-b` exists but is not used.
- Reboot and confirm `/var` and `/home` data persists.

## Deployable Gate

- Fresh image boots to GNOME Initial Setup from `root-a`.
- GNOME Initial Setup can create the first user successfully.
- Existing single-slot behavior is preserved from the user's perspective.
- No `/etc` persistence mechanism has been introduced in this phase.

## Risks

- Repartitioning changes image geometry and may break assumptions in QEMU or mkosi output.
- Moving `/var` out of the root slot can expose services that assume files created during image build remain on the root filesystem.
- Incorrect partition labels can make the image unbootable.
- Making the root slot read-only before `/etc` persistence exists will break first-user creation.
