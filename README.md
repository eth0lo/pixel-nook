# Arch GNOME Bootable Image Builder

This repository builds a bootable Arch Linux GNOME disk image.

The build toolchain is portable: mkosi and the required Arch build tools run inside a Podman container. The host system only needs Podman to build the image, instead of needing mkosi or Arch packaging tools installed locally.

Build output is written to `out/`, including the bootable UEFI disk image at `out/arch-gnome.raw`.

The disk image now uses a Phase 2 A/B-capable layout: a shared ESP, manually bootable `root-a` and `root-b` slots, and separate shared `var` and `home` partitions. `root-a` remains the default boot path, `root-b` is a manual alternate, and only `/home`, `/var`, and an allowlisted set of identity files under `/etc` are guaranteed to stay aligned across slot switches.

## What This Produces

After a successful build, `out/` contains:

- `arch-gnome.raw`: the bootable UEFI disk image
- `arch-gnome.vmlinuz`: the generated kernel artifact
- `arch-gnome.initrd`: the generated initrd artifact
- `initrd.cpio.zst`: the initrd archive generated during the build

Inside `arch-gnome.raw`, the Phase 2 partition schema is:

- `esp`: shared EFI System Partition used by UEFI and `systemd-boot`
- `root-a`: the default booted root slot in this phase
- `root-b`: a manually selectable alternate root slot
- `var`: shared writable `/var`
- `home`: shared writable `/home`

## Phase 2 Behavior

- `systemd-boot` shows a visible menu with `Arch GNOME (root-a)` and `Arch GNOME (root-b)`.
- The menu defaults to `root-a` after a short timeout.
- Both root slots stay mounted read-write in this phase.
- Shared cross-slot continuity is guaranteed only for `/home`, `/var`, and these `/etc` files: `passwd`, `shadow`, `group`, `gshadow`, `subuid`, and `subgid`.
- Automatic slot switching, rollback, inactive-slot updates, and generalized `/etc` persistence are not part of Phase 2.

## Requirements

To build the image, the host needs:

- Podman
- Permission to run privileged containers

To run the image on Fedora, the host also needs:

- QEMU
- edk2 OVMF firmware
- KVM support, recommended for performance

## Build The Toolchain Container

Build the portable mkosi toolchain container:

```bash
podman build -t arch-mkosi .
```

The default build environment uses the Arch Linux Archive snapshot from `2026/05/01`. To use a different Arch package snapshot, pass a different `ARCH_SNAPSHOT` build argument:

```bash
podman build \
  --build-arg ARCH_SNAPSHOT=2026/05/01 \
  -t arch-mkosi:2026-05-01 .
```

## Build The Bootable Image

Create the output directory and run mkosi inside the toolchain container:

```bash
mkdir -p out

podman run --rm --privileged \
  -v "$PWD/mkosi:/mkosi" \
  -v "$PWD/out:/output" \
  arch-mkosi /output
```

The mkosi project is mounted into the container at `/mkosi`, and build output is written to `/output`, which maps to `out/` on the host.

## Rebuild The Image

To rebuild over an existing image, pass `--force` to mkosi through the container entrypoint:

```bash
podman run --rm --privileged \
  -v "$PWD/mkosi:/mkosi" \
  -v "$PWD/out:/output" \
  arch-mkosi /output --force
```

## Run The Image On Fedora

Install QEMU and OVMF firmware:

```bash
sudo dnf install qemu-system-x86 edk2-ovmf
```

Create a writable UEFI variable store for the VM. This file stores per-VM firmware state, such as boot entries and display mode:

```bash
cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
```

Launch the image with QEMU:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -machine pc-q35-10.1 \
  -cpu host \
  -m 4096 \
  -smp 4 \
  -drive if=pflash,format=qcow2,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2 \
  -drive if=pflash,format=qcow2,file=out/archlinux_VARS.qcow2 \
  -drive if=none,id=osdisk,file=out/arch-gnome.raw,format=raw \
  -device virtio-blk-pci,drive=osdisk,bootindex=1 \
  -device virtio-vga,xres=1920,yres=1080,edid=on \
  -display gtk,zoom-to-fit=off \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0
```

The firmware code image is attached read-only. The NVRAM image is attached read-write so firmware settings can persist between boots.

## Run Modes

The QEMU command above attaches `out/arch-gnome.raw` read-write. Changes made inside the VM are written back to the disk image.

For disposable testing, create a qcow2 overlay and boot that instead. The VM can write normally, but the base image remains unchanged:

```bash
qemu-img create -f qcow2 -b out/arch-gnome.raw -F raw out/arch-gnome.overlay.qcow2
```

Then replace this disk line in the QEMU command:

```bash
-drive if=none,id=osdisk,file=out/arch-gnome.raw,format=raw
```

With this overlay-backed disk line:

```bash
-drive if=none,id=osdisk,file=out/arch-gnome.overlay.qcow2,format=qcow2
```

To discard VM changes, delete the overlay:

```bash
rm -f out/arch-gnome.overlay.qcow2
```

## Reset VM Firmware State

If the VM keeps an old display mode or stale firmware boot state, recreate `out/archlinux_VARS.qcow2` from the OVMF template and start it again:

```bash
rm -f out/archlinux_VARS.qcow2
cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
```

## Project Layout

- `Containerfile`: builds the portable mkosi build environment
- `docker-entrypoint.sh`: runs mkosi inside the container
- `mkosi/mkosi.conf`: defines the Arch GNOME image
- `mkosi/mkosi.repart/`: defines the fixed Phase 2 disk layout
- `mkosi/mkosi.extra/`: files copied into the image
- `mkosi/mkosi.postinst`: post-install customization run by mkosi
- `mkosi/mkosi.finalize`: final build customization run by mkosi
- `handoff/phase-1-validation.md`: manual validation checklist for the Phase 1 layout
- `handoff/phase-2-validation.md`: manual validation checklist for the Phase 2 layout
- `out/`: generated build output

## Notes

`--privileged` is usually required because mkosi creates and mounts disk images during the build.

For stricter reproducibility, pin the container base image by digest instead of using `archlinux:latest`.
