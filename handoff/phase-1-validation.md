# Phase 1 Validation

This Phase 1 layout is for fresh images only. Existing single-slot images are not migrated in place.

## Host Requirements

- `podman` with permission to run `--privileged` containers
- `qemu-system-x86_64`
- `edk2` OVMF firmware at `/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2` and `/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2`
- KVM support is recommended for usable VM performance

## Expected In Phase 1

- `root-b` exists as an ext4 partition but is not booted.
- Only `root-a` has an active boot path.
- The root filesystem is mounted read-write.
- The ESP is not mounted by default.
- No `/etc` persistence mechanism exists yet.

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

   Expected result: `out/arch-gnome.raw`, `out/arch-gnome.vmlinuz`, `out/arch-gnome.initrd`, and `out/initrd.cpio.zst` are produced with their existing names.

3. Create a writable UEFI variable store for the VM.

   ```bash
   cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
   ```

4. Boot the image in QEMU and complete GNOME Initial Setup.

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

   Expected result: first-user creation succeeds and the new user can log in without additional recovery or manual partition work.

   If the VM keeps stale firmware state between runs, recreate the NVRAM file before retrying:

   ```bash
   rm -f out/archlinux_VARS.qcow2
   cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
   ```

5. Confirm the guest booted with UEFI.

   ```bash
   test -d /sys/firmware/efi && printf 'uefi\n'
   ```

   Expected result: the command prints `uefi`.

6. Confirm the partition labels and filesystem types.

   ```bash
   lsblk -f
   ```

   Expected result: the image exposes partitions labeled `esp`, `root-a`, `root-b`, `var`, and `home`. `root-a`, `root-b`, `var`, and `home` use `ext4`.

7. Confirm the running root slot is `root-a`.

   ```bash
   findmnt /
   cat /proc/cmdline
   ```

   Expected result: `/` resolves to the partition labeled `root-a`, and the kernel command line includes `root=PARTLABEL=root-a rw`.

8. Confirm `/var` and `/home` are mounted from their dedicated partitions.

   ```bash
   findmnt /var
   findmnt /home
   ```

   Expected result: `/var` is mounted from `PARTLABEL=var` and `/home` is mounted from `PARTLABEL=home`.

9. Confirm `root-b` exists but is not mounted.

   ```bash
   findmnt | grep root-b
   lsblk -f
   ```

   Expected result: `lsblk -f` shows `root-b`, and `findmnt | grep root-b` returns no matches.

10. Inspect the ESP contents.

   ```bash
   sudo mkdir -p /mnt/esp
   sudo mount /dev/disk/by-partlabel/esp /mnt/esp
   find /mnt/esp -maxdepth 3 -type f
   ```

   Expected result: the ESP contains `systemd-boot` files and only the intended `root-a` boot entry for this image.

11. Confirm `/var` and `/home` survive reboot.

   ```bash
   sudo touch /var/lib/phase-1-var-marker
   touch /home/$USER/phase-1-home-marker
   sudo reboot
   ```

   After reboot, run:

   ```bash
   ls -l /var/lib/phase-1-var-marker
   ls -l /home/$USER/phase-1-home-marker
   ```

   Expected result: both marker files still exist after reboot.

12. Confirm the root filesystem is still mounted read-write after login and reboot.

    ```bash
    findmnt -no OPTIONS /
    ```

    Expected result: the mount options for `/` include `rw`.
