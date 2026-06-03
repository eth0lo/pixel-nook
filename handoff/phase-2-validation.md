# Phase 2 Validation

This Phase 2 layout is for fresh images only. Existing single-slot images are not migrated in place.

## Host Requirements

- `podman` with permission to run `--privileged` containers
- `qemu-system-x86_64`
- `edk2` OVMF firmware at `/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2` and `/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2`
- KVM support is recommended for usable VM performance

## Expected In Phase 2

- Both `root-a` and `root-b` contain bootable OS roots.
- `systemd-boot` shows both slots and defaults to `root-a` after a short timeout.
- The root filesystem stays mounted read-write on both slots.
- `/var` and `/home` are shared between slots.
- `/var/lib/ab-boot/etc/` is the canonical source for the allowlisted identity files.
- Only the allowlisted identity files under `/etc` are guaranteed to stay aligned across slot switches.

## Validate The Image

1. Build the mkosi toolchain container.

   ```bash
   podman build --pull=always -t arch-mkosi .
   ```

   For a fully clean rebuild of the container image, use:

   ```bash
   podman build --pull=always --no-cache -t arch-mkosi .
   ```

2. Build the image.

   ```bash
   mkdir -p out
   podman run --rm --privileged \
     -v "$PWD/mkosi:/mkosi" \
     -v "$PWD/out:/output" \
     arch-mkosi /output
   ```

   Expected result: `out/arch-gnome.raw`, `out/arch-gnome.vmlinuz`, `out/arch-gnome.initrd`, and `out/initrd.cpio.zst` are produced.

3. Create a writable UEFI variable store for the VM.

   ```bash
   cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
   ```

4. Boot the image in QEMU.

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

5. Confirm the `systemd-boot` menu is visible, lists `Arch GNOME (root-a)` and `Arch GNOME (root-b)`, and defaults to `root-a` after a short timeout.

6. Complete GNOME Initial Setup on `root-a` and log in.

7. Confirm the guest booted with UEFI.

   ```bash
   test -d /sys/firmware/efi && printf 'uefi\n'
   ```

   Expected result: the command prints `uefi`.

8. Confirm the partition labels and filesystem types.

   ```bash
   lsblk -f
   ```

   Expected result: the image exposes filesystems labeled `ESP`, `root-a`, `root-b`, `var`, and `home`. `root-a`, `root-b`, `var`, and `home` use `ext4`.

9. Confirm the running root slot is `root-a`.

   ```bash
   findmnt /
   cat /proc/cmdline
   cat /usr/lib/ab-boot/slot
   ```

   Expected result: `/` is mounted from the partition labeled `root-a`, the kernel command line includes `root=PARTLABEL=root-a rw`, and the slot marker prints `root-a`.

10. Confirm the shared mounts are present.

    ```bash
    findmnt /var
    findmnt /home
    ```

    Expected result: `/var` is mounted from the partition labeled `var` and `/home` is mounted from the partition labeled `home`.

11. Confirm the persisted identity files exist under `/var/lib/ab-boot/etc/`.

    ```bash
    ls -l /var/lib/ab-boot/etc
    ```

    Expected result: the directory contains `passwd`, `shadow`, `group`, `gshadow`, `subuid`, `subgid`, and `machine-id`.

12. Confirm each allowlisted `/etc` file matches the persisted copy under `/var/lib/ab-boot/etc/`.

    ```bash
    sha256sum /var/lib/ab-boot/etc/passwd /etc/passwd
    sha256sum /var/lib/ab-boot/etc/shadow /etc/shadow
    sha256sum /var/lib/ab-boot/etc/group /etc/group
    sha256sum /var/lib/ab-boot/etc/gshadow /etc/gshadow
    sha256sum /var/lib/ab-boot/etc/subuid /etc/subuid
    sha256sum /var/lib/ab-boot/etc/subgid /etc/subgid
    sha256sum /var/lib/ab-boot/etc/machine-id /etc/machine-id
    ```

    Expected result: each command prints two identical hashes.

13. Confirm the persisted sensitive files keep the expected ownership and permissions both at the source and at runtime.

    ```bash
    stat -c '%U:%G %a %n' \
      /var/lib/ab-boot/etc/shadow \
      /var/lib/ab-boot/etc/gshadow \
      /var/lib/ab-boot/etc/subuid \
      /var/lib/ab-boot/etc/subgid \
      /var/lib/ab-boot/etc/machine-id \
      /etc/shadow \
      /etc/gshadow \
      /etc/subuid \
      /etc/subgid \
      /etc/machine-id
    ```

    Expected result: the persisted copies and their `/etc` runtime views match.

14. Inspect the ESP and confirm both loader entries exist.

    ```bash
    sudo mkdir -p /mnt/esp
    sudo mount /dev/disk/by-partlabel/esp /mnt/esp
    sudo grep -RE '^(title|linux|initrd|options) ' /mnt/esp/loader/entries/*.conf
    ```

    Expected result:

    - One entry is titled `Arch GNOME (root-a)` and its options line includes `root=PARTLABEL=root-a rw`.
    - One entry is titled `Arch GNOME (root-b)` and its options line includes `root=PARTLABEL=root-b rw`.
    - Both entries reference the same shared kernel and initrd payload paths.

15. Create shared-state markers on `root-a`.

    ```bash
    sudo touch /var/lib/phase-2-var-marker
    touch /home/$USER/phase-2-home-marker
    ls -l /var/lib/phase-2-var-marker
    ls -l /home/$USER/phase-2-home-marker
    ```

    Expected result: both marker files exist immediately after creation.

16. Reboot and select `Arch GNOME (root-b)` from the `systemd-boot` menu.

17. Confirm the running root slot is `root-b`.

    ```bash
    findmnt /
    cat /proc/cmdline
    cat /usr/lib/ab-boot/slot
    ```

    Expected result: `/` is mounted from the partition labeled `root-b`, the kernel command line includes `root=PARTLABEL=root-b rw`, and the slot marker prints `root-b`.

18. Confirm the same user created on `root-a` can log in on `root-b` without re-running GNOME Initial Setup.

19. Confirm shared state and persisted identity restore still work on `root-b`.

    ```bash
    ls -l /var/lib/phase-2-var-marker
    ls -l /home/$USER/phase-2-home-marker
    sha256sum /var/lib/ab-boot/etc/passwd /etc/passwd
    sha256sum /var/lib/ab-boot/etc/shadow /etc/shadow
    sha256sum /var/lib/ab-boot/etc/group /etc/group
    sha256sum /var/lib/ab-boot/etc/gshadow /etc/gshadow
    sha256sum /var/lib/ab-boot/etc/subuid /etc/subuid
    sha256sum /var/lib/ab-boot/etc/subgid /etc/subgid
    sha256sum /var/lib/ab-boot/etc/machine-id /etc/machine-id
    ```

    Expected result: the markers created in step 15 are still present, and each `sha256sum` command prints two identical hashes.

20. Reboot and let the timeout return to the default `root-a` entry.

21. Confirm `root-a` still works after the round-trip.

    ```bash
    findmnt /
    cat /usr/lib/ab-boot/slot
    ls -l /var/lib/phase-2-var-marker
    ls -l /home/$USER/phase-2-home-marker
    ```

    Expected result: the system boots back into `root-a`, the slot marker prints `root-a`, and the shared-state markers are still present.
