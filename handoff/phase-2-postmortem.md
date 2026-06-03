# Phase 2 Postmortem

This note captures the wrong assumptions that blocked Phase 2 from reaching its goals, the visible failure modes, and the fixes that made manual slot boot work.

## Goal That Failed Initially

Phase 2 was supposed to produce a fresh-image-only A/B-capable layout that:

- boots both `root-a` and `root-b` from a visible `systemd-boot` menu
- keeps `root-a` as the default entry
- shares `/var` and `/home` across both slots
- preserves the minimum identity files needed for GNOME Initial Setup and cross-slot login
- keeps both root slots writable in this phase

The first Phase 2 image builds produced the right partitions and booted farther than Phase 1, but they did not actually satisfy the manual slot boot and cross-slot login goals.

## Wrong Assumption 1

`mkosi.finalize` was assumed to run after mkosi had already generated the bootloader entry that Phase 2 wanted to clone into `root-b`.

What actually happened:

- the Phase 2 finalize logic expected exactly one generated loader entry under `/boot/loader/entries`
- current mkosi runs `FinalizeScripts=` before the final boot artifacts are ready for this image layout
- the build failed with `Expected exactly one generated loader entry under /buildroot/boot/loader/entries before deriving root-b`

That meant the image never completed even though package installation, root population, and most bootloader work had already succeeded.

The broken assumption showed up in the original finalize logic:

```sh
set -- "$entries_dir"/*.conf

if [ ! -e "$1" ] || [ "$#" -ne 1 ]; then
    printf '%s\n' "Expected exactly one generated loader entry under $entries_dir before deriving root-b" >&2
    exit 1
fi
```

Fix:

- remove boot-entry rewriting from `mkosi.finalize`
- move Phase 2 entry derivation into `mkosi.postoutput`
- patch the finished raw image after mkosi has generated the final ESP contents

Why this fixed it:

- `PostOutputScripts=` runs after mkosi has created the raw disk image and copied the final ESP payloads
- the Phase 2 logic can now inspect the real loader entry that ships in the image
- `root-b` can be derived from the actual `root-a` entry instead of guessing earlier build state

## Wrong Assumption 2

Setting `Bootloader=systemd-boot` was assumed to keep generating a Type 1 boot entry in `loader/entries/`.

What actually happened:

- current mkosi defaults `UnifiedKernelImages=auto`
- when UKI tooling is available, mkosi can stop producing the exact Type 1 loader-entry shape that the Phase 2 entry-duplication logic expected
- that made the Phase 2 implementation depend on mkosi behavior that was no longer stable across toolchain versions

Fix:

```ini
[Content]
Bootable=yes
Bootloader=systemd-boot
UnifiedKernelImages=none
KernelCommandLine=root=PARTLABEL=root-a rw systemd.gpt_auto=no
```

Why this fixed it:

- Phase 2 explicitly stays on the Boot Loader Specification Type 1 path
- the shipped ESP continues to contain `loader/entries/*.conf`
- the Phase 2 `root-b` entry can be derived deterministically from the generated `root-a` entry

## Wrong Assumption 3

Bind-mounting the allowlisted identity files directly onto `/etc` was assumed to be compatible with GNOME Initial Setup and `useradd`.

What actually happened:

- the first Phase 2 persistence design mounted files such as `/var/lib/ab-boot/etc/passwd` directly onto `/etc/passwd`
- GNOME Initial Setup reaches `useradd` during first-user creation
- `useradd` expects to update account databases using normal writable filesystem semantics, including atomic replacement behavior
- the setup UI failed with `Failed to run useradd: Child process exited with code 1`

The broken assumption showed up in the original `fstab` plan:

```fstab
/var/lib/ab-boot/etc/passwd /etc/passwd none bind,x-systemd.requires-mounts-for=/var/lib/ab-boot/etc/passwd 0 0
/var/lib/ab-boot/etc/shadow /etc/shadow none bind,x-systemd.requires-mounts-for=/var/lib/ab-boot/etc/shadow 0 0
/var/lib/ab-boot/etc/group /etc/group none bind,x-systemd.requires-mounts-for=/var/lib/ab-boot/etc/group 0 0
```

Fix:

- keep `/etc` writable in Phase 2
- restore the allowlisted identity files from `/var/lib/ab-boot/etc/` into `/etc` before login services start
- persist later changes back into `/var/lib/ab-boot/etc/` with a small systemd path/service pair

The replacement pieces are:

- `/usr/lib/ab-boot/account-files-sync`
- `ab-boot-account-files-restore.service`
- `ab-boot-account-files-watch.path`
- `ab-boot-account-files-sync.service`

Why this fixed it:

- account-management tools now operate on ordinary writable files under `/etc`
- the minimum Phase 2 identity state still stays aligned across slot switches
- the persistence scope remains narrow instead of becoming generalized `/etc` sync

## Wrong Assumption 4

The slot-local marker copy rule in the repart configuration was assumed to reliably land `/usr/lib/ab-boot/slot` inside both root partitions.

What actually happened:

- the image built successfully
- validation in the guest failed because `cat /usr/lib/ab-boot/slot` reported that the file did not exist
- inspection of the built root partition showed `/usr/lib/ab-boot/account-files-sync` existed but `/usr/lib/ab-boot/slot` did not

The original intent was visible in the repart files:

```ini
[Partition]
Label=root-a
CopyFiles=/
ExcludeFiles=/efi /var /home /usr/lib/ab-boot/slot /usr/lib/ab-boot/slot-seeds
MakeDirectories=/efi /var /home /usr/lib/ab-boot
CopyFiles=/usr/lib/ab-boot/slot-seeds/root-a/slot:/usr/lib/ab-boot/slot
```

Fix:

- keep the slot seed generation in `mkosi.finalize`
- stamp the final `/usr/lib/ab-boot/slot` file directly into the finished `root-a` and `root-b` partitions during `mkosi.postoutput`

Why this fixed it:

- the slot marker is now written into the exact root partitions that ship in `arch-gnome.raw`
- validation of `root-a` and `root-b` no longer depends on uncertain repart copy behavior
- the slot marker still stays slot-local, which is the only intentional content difference between the two root slots in this phase

## Wrong Assumption 5

The Phase 2 handoff was assumed to be clear enough for non-technical validation even when it used shell loops and tool-specific expectations.

What actually happened:

- the validation note used shell loops for comparing persisted identity files
- a proposed `cmp`-based check assumed tooling that was not available in the guest image
- marker expectations could be read as if the files should already exist before the step that created them

Fix:

- rewrite the affected validation steps as short, repeated commands
- use `sha256sum` comparisons instead of loops or `cmp`
- make marker expectations explicit at the step where the markers are created

Why this fixed it:

- the handoff is now easier to execute with basic tab-completable commands
- validation no longer depends on shell fluency
- the documented expectations better match the actual image behavior

## Final Working State

The working Phase 2 image now has:

- `root-a` and `root-b` both populated with a bootable OS root
- two visible `systemd-boot` entries in the ESP
- `root-a` as the default boot target and `root-b` as a manual alternate
- a slot-local `/usr/lib/ab-boot/slot` marker in each root partition
- shared `/var` and `/home` partitions
- a minimum persisted identity store under `/var/lib/ab-boot/etc/`
- writable `/etc` plus targeted restore/persist logic for the allowlisted identity files

The final 20G image layout remains:

```text
esp     1G
root-a  6G
root-b  6G
var     3G
home    4G
```

The key lesson from Phase 2 is that making both slots bootable was not just a partition-layout problem. It depended on understanding mkosi's real build order, pinning boot-entry format behavior explicitly, preserving writable semantics for account management, and validating the final raw image rather than assuming intermediate build-stage intent became shipped state.
