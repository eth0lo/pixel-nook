# Phase 1 Postmortem

This note captures the wrong assumptions that blocked Phase 1 from reaching its goals, the visible failure modes, and the fixes that made the image bootable.

## Goal That Failed Initially

Phase 1 was supposed to produce a fresh-image-only A/B-capable layout that:

- boots from `root-a`
- leaves `root-b` inactive
- mounts shared `/var` and `/home`
- remains writable for GNOME Initial Setup

The first image builds satisfied the partition geometry, but they did not actually produce a bootable guest.

## Wrong Assumption 1

`Format=` plus partition sizing was assumed to be enough to produce a usable root filesystem.

What actually happened:

- `systemd-repart` created the partitions
- `root-a`, `root-b`, `var`, and `home` existed
- but the partitions were effectively empty except for filesystem metadata

That meant QEMU had a disk image with the right labels but no operating system payload in `root-a`.

The broken assumption showed up in the original repart files:

```ini
[Partition]
Type=root
Label=root-a
Format=ext4
SizeMinBytes=6G
SizeMaxBytes=6G
```

There was no instruction telling `systemd-repart` to copy the built tree into `root-a`.

Fix:

```ini
[Partition]
Type=root
Label=root-a
Format=ext4
SizeMinBytes=6G
SizeMaxBytes=6G
CopyFiles=/
ExcludeFiles=/efi /var /home
MakeDirectories=/efi /var /home
```

Why this fixed it:

- `CopyFiles=/` copies the staged OS tree into `root-a`
- `ExcludeFiles=/efi /var /home` avoids duplicating data that belongs elsewhere
- `MakeDirectories=/efi /var /home` recreates the mountpoints in `root-a`

## Wrong Assumption 2

Creating a bootloader entry in the ESP was assumed to be enough for UEFI boot.

What actually happened:

- the ESP contained `systemd-boot`
- the ESP contained a loader entry
- but the entry referenced kernel and initrd paths that were not present in the ESP

The loader entry looked like this:

```text
title arch-gnome 7.0.3-arch1-1
version 7.0.3-arch1-1
linux /arch-gnome/7.0.3-arch1-1/vmlinuz
options root=PARTLABEL=root-a rw
initrd /arch-gnome/initrd
initrd /arch-gnome/7.0.3-arch1-1/kernel-modules.initrd
```

But the ESP initially only had the bootloader files and loader metadata, not `/arch-gnome/...`.

That caused firmware or `systemd-boot` to fall back to an interactive firmware interface instead of booting Linux.

Fix:

```ini
[Partition]
Type=esp
Label=esp
Format=vfat
SizeMinBytes=1G
SizeMaxBytes=1G
CopyFiles=/efi/EFI:/EFI
CopyFiles=/efi/loader:/loader
CopyFiles=/boot/EFI:/EFI
CopyFiles=/boot/loader:/loader
CopyFiles=/boot/arch-gnome:/arch-gnome
```

Why this fixed it:

- `systemd-boot` binaries land in the ESP
- loader entries land in the ESP
- the kernel and initrd payload now land at the exact paths referenced by the loader entry

## Wrong Assumption 3

Separate `/var` and `/home` partitions were assumed to be valid once `fstab` existed.

What actually happened:

- `fstab` mounted `PARTLABEL=var` and `PARTLABEL=home`
- but the `var` partition was initially empty
- services and first-boot behavior depend on files that already exist under `/var` in the built image

The image already had this mount plan:

```fstab
# Phase 1 mounts shared writable state outside the root slot.
PARTLABEL=var /var ext4 defaults 0 2
PARTLABEL=home /home ext4 defaults 0 2
```

But that alone did not populate the `var` partition.

Fix:

```ini
[Partition]
Type=var
Label=var
Format=ext4
SizeMinBytes=3G
SizeMaxBytes=3G
CopyFiles=/var:/
```

Why this fixed it:

- the built `/var` tree is copied into the dedicated `var` partition before first boot
- mounting `/var` no longer hides required state that only existed in `root-a`

## Wrong Assumption 4

The early `No space left on device` failure was assumed to mean the host machine had run out of free disk space.

What actually happened:

- the host still had significant free space
- the failure came from image construction, not from the workstation filesystem filling up
- the error was about the target filesystem population path, not `/home` or `/`

Host space at verification time was:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme1n1p3  476G  421G   54G  89% /
```

The successful rebuilt image showed the actual `root-a` usage was much smaller than the earlier failures suggested:

```text
root-a total_bytes=6249086976
root-a used_bytes=4281098240
root-a used_gib=3.99
root-a use_pct=68.0
```

Why this mattered:

- the investigation initially chased host free space
- the real problem was missing or misdirected image population rules
- once `root-a`, `var`, and the ESP were populated correctly, the original `6G` slot size worked again

## Wrong Assumption 5

Fresh QEMU boots were assumed to always reflect the newly built image.

What actually happened:

- OVMF keeps persistent NVRAM state in `out/archlinux_VARS.qcow2`
- stale firmware state can continue to point at old entries or failed boot paths
- that made repeated tests harder to interpret

The recovery step that must be part of troubleshooting is:

```bash
rm -f out/archlinux_VARS.qcow2
cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
```

Why this fixed it:

- it forces UEFI to rescan the current image state
- it removes stale boot entries from previous failed runs

## Final Working State

The working Phase 1 image now has:

- `esp` with `systemd-boot`, loader entries, and `/arch-gnome/...` payloads
- `root-a` populated with the built OS tree
- `var` populated from the built `/var`
- `home` created as a dedicated empty writable partition
- `root-b` present as an inactive placeholder

The final 20G image layout remains:

```text
esp     1G
root-a  6G
root-b  6G
var     3G
home    4G
```

The key lesson from Phase 1 is that correct partition geometry is not enough. For a mkosi disk image built through `systemd-repart`, every partition that must contain runtime content needs explicit population rules, and the ESP contents must match the exact paths referenced by the bootloader entries.
