# Phase 3 Validation

This Phase 3 layout is for fresh images only. Existing single-slot images are not migrated in place.

## Host Requirements

- `podman` with permission to run `--privileged` containers
- `qemu-system-x86_64`
- `edk2` OVMF firmware at `/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2` and `/usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2`
- KVM support is recommended for usable VM performance

## Expected In Phase 3

- Both `root-a` and `root-b` contain bootable OS roots.
- `systemd-boot` shows both slots and defaults to `root-a` after a short timeout.
- The root filesystem stays mounted read-write on both slots.
- `/var` and `/home` are shared between slots.
- `/var/lib/ab-boot/slots/` contains the canonical per-slot boot-health state.
- `abctl health` is unconfirmed before GDM becomes active and healthy after the current boot is recorded.
- Non-graphical boots remain unconfirmed.

## Validate The Image

1. Build the mkosi toolchain container.

   ```bash
   podman build --pull=always -t arch-mkosi .
   ```

2. Build the image.

   ```bash
   mkdir -p out
   podman run --rm --privileged \
     -v "$PWD/mkosi:/mkosi" \
     -v "$PWD/out:/output" \
     arch-mkosi /output
   ```

3. Create a writable UEFI variable store for the VM.

   ```bash
   cp /usr/share/edk2/ovmf/OVMF_VARS_4M.qcow2 out/archlinux_VARS.qcow2
   ```

4. Boot the image in QEMU and leave the default `root-a` entry selected.

5. After the login screen appears, switch to a text console or log in and confirm the slot and health view on `root-a`.

   ```bash
   abctl current-slot
   abctl inactive-slot
   abctl health
   abctl status
   ```

   Expected result:

   - `abctl current-slot` prints `root-a`.
   - `abctl inactive-slot` prints `root-b`.
   - `abctl health` prints `healthy` and exits `0` after GDM is active.
   - `abctl status` shows both slot files plus `root-a` current-boot confirmation as `yes`.

6. Confirm the shared slot-state files exist and the current boot ID was persisted for `root-a`.

   ```bash
   cat /var/lib/ab-boot/slots/root-a.env
   cat /var/lib/ab-boot/slots/root-b.env
   cat /proc/sys/kernel/random/boot_id
   ```

   Expected result:

   - `root-a.env` shows `BOOT_SUCCESS=1`.
   - `root-a.env` `LAST_BOOT_ID` matches `/proc/sys/kernel/random/boot_id`.
   - `root-b.env` still shows `BOOT_SUCCESS=0` until `root-b` is booted successfully.

7. Reboot and select `Arch GNOME (root-b)` from the `systemd-boot` menu.

8. Confirm the mirrored slot and health view on `root-b`.

   ```bash
   abctl current-slot
   abctl inactive-slot
   abctl health
   abctl status
   ```

   Expected result:

   - `abctl current-slot` prints `root-b`.
   - `abctl inactive-slot` prints `root-a`.
   - `abctl health` prints `healthy` and exits `0` after GDM is active.
   - `abctl status` shows `root-b` current-boot confirmation as `yes`.

9. Confirm the shared slot-state files persisted across the slot switch.

   ```bash
   cat /var/lib/ab-boot/slots/root-a.env
   cat /var/lib/ab-boot/slots/root-b.env
   ```

   Expected result: both files still exist under shared `/var/lib/ab-boot/slots/`, and each slot file retains the latest recorded success for that slot.

10. Confirm the success unit is ordered after GDM.

    ```bash
    systemctl status ab-boot-mark-boot-success.service
    systemctl show -p After ab-boot-mark-boot-success.service
    ```

    Expected result: the service completed successfully on graphical boot, and its `After=` property includes `gdm.service`.

11. Confirm a non-graphical boot remains unconfirmed.

    11.1 On the `systemd-boot` entry you want to test, press `e` and append `systemd.unit=multi-user.target` to the kernel command line for a one-time boot.

    11.2 Boot the edited entry and run:

    ```bash
    abctl current-slot
    abctl health
    abctl status
    ```

    Expected result:

    - `abctl current-slot` still reports the active slot correctly.
    - `abctl health` prints `unconfirmed` and exits `1`.
    - `abctl status` shows historical success for that slot if it existed earlier, but `current boot confirmed: no` for the current boot.
