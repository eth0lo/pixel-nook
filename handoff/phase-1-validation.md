# Phase 1 Validation

This Phase 1 layout is for fresh images only. Existing single-slot images are not migrated in place.

## Expected In Phase 1

- `root-b` exists as an ext4 partition but is not booted.
- Only `root-a` has an active boot path.
- The root filesystem is mounted read-write.
- The ESP is not mounted by default.
- No `/etc` persistence mechanism exists yet.

## Validate The Image

1. Build the image with the documented container workflow.

   Expected result: `out/arch-gnome.raw`, `out/arch-gnome.vmlinuz`, `out/arch-gnome.initrd`, and `out/initrd.cpio.zst` are produced with their existing names.

2. Boot the image in QEMU using the `README.md` instructions and complete GNOME Initial Setup.

   Expected result: first-user creation succeeds and the new user can log in without additional recovery or manual partition work.

3. Confirm the guest booted with UEFI.

   ```bash
   test -d /sys/firmware/efi && printf 'uefi\n'
   ```

   Expected result: the command prints `uefi`.

4. Confirm the partition labels and filesystem types.

   ```bash
   lsblk -f
   ```

   Expected result: the image exposes partitions labeled `esp`, `root-a`, `root-b`, `var`, and `home`. `root-a`, `root-b`, `var`, and `home` use `ext4`.

5. Confirm the running root slot is `root-a`.

   ```bash
   findmnt /
   cat /proc/cmdline
   ```

   Expected result: `/` resolves to the partition labeled `root-a`, and the kernel command line includes `root=PARTLABEL=root-a rw`.

6. Confirm `/var` and `/home` are mounted from their dedicated partitions.

   ```bash
   findmnt /var
   findmnt /home
   ```

   Expected result: `/var` is mounted from `PARTLABEL=var` and `/home` is mounted from `PARTLABEL=home`.

7. Confirm `root-b` exists but is not mounted.

   ```bash
   findmnt | grep root-b
   lsblk -f
   ```

   Expected result: `lsblk -f` shows `root-b`, and `findmnt | grep root-b` returns no matches.

8. Inspect the ESP contents.

   ```bash
   sudo mkdir -p /mnt/esp
   sudo mount /dev/disk/by-partlabel/esp /mnt/esp
   find /mnt/esp -maxdepth 3 -type f
   ```

   Expected result: the ESP contains `systemd-boot` files and only the intended `root-a` boot entry for this image.

9. Confirm `/var` and `/home` survive reboot.

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

10. Confirm the root filesystem is still mounted read-write after login and reboot.

    ```bash
    findmnt -no OPTIONS /
    ```

    Expected result: the mount options for `/` include `rw`.
