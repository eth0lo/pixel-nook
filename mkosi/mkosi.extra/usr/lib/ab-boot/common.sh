#!/bin/sh

ab_boot_die() {
    printf '%s\n' "$*" >&2
    exit "${AB_BOOT_EXIT_CODE:-1}"
}

ab_boot_state_dir() {
    printf '%s\n' /var/lib/ab-boot/slots
}

ab_boot_state_file() {
    case "$1" in
        root-a|root-b)
            printf '%s/%s.env\n' "$(ab_boot_state_dir)" "$1"
            ;;
        *)
            ab_boot_die "unknown slot: $1"
            ;;
    esac
}

ab_boot_current_slot() {
    root_source=$(findmnt -no SOURCE -T / 2>/dev/null || true)

    [ -n "$root_source" ] || ab_boot_die 'could not determine the device mounted at /'

    root_source=$(readlink -f "$root_source" 2>/dev/null || printf '%s' "$root_source")
    partlabel=$(lsblk -no PARTLABEL "$root_source" 2>/dev/null || true)

    case "$partlabel" in
        root-a|root-b)
            printf '%s\n' "$partlabel"
            ;;
        *)
            ab_boot_die "could not derive current slot from /: source=$root_source label=${partlabel:-unknown}"
            ;;
    esac
}

ab_boot_inactive_slot() {
    case "$(ab_boot_current_slot)" in
        root-a)
            printf '%s\n' root-b
            ;;
        root-b)
            printf '%s\n' root-a
            ;;
    esac
}

ab_boot_current_boot_id() {
    boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)

    case "$boot_id" in
        ''|*[!0-9a-f-]*)
            ab_boot_die 'could not determine current boot ID'
            ;;
        *)
            printf '%s\n' "$boot_id"
            ;;
    esac
}

ab_boot_read_state() {
    slot="$1"
    state_file=$(ab_boot_state_file "$slot")

    [ -r "$state_file" ] || ab_boot_die "slot state file is not readable: $state_file"

    AB_BOOT_SUCCESS=
    AB_LAST_BOOT_ID=
    AB_LAST_SUCCESS_EPOCH=
    seen_boot_success=0
    seen_last_boot_id=0
    seen_last_success_epoch=0

    while IFS='=' read -r key value || [ -n "$key" ]; do
        case "$key" in
            ''|'#'*)
                continue
                ;;
            BOOT_SUCCESS)
                AB_BOOT_SUCCESS="$value"
                seen_boot_success=1
                ;;
            LAST_BOOT_ID)
                AB_LAST_BOOT_ID="$value"
                seen_last_boot_id=1
                ;;
            LAST_SUCCESS_EPOCH)
                AB_LAST_SUCCESS_EPOCH="$value"
                seen_last_success_epoch=1
                ;;
            *)
                ab_boot_die "unexpected key in slot metadata: $key"
                ;;
        esac
    done < "$state_file"

    [ "$seen_boot_success" -eq 1 ] || ab_boot_die "missing BOOT_SUCCESS in $state_file"
    [ "$seen_last_boot_id" -eq 1 ] || ab_boot_die "missing LAST_BOOT_ID in $state_file"
    [ "$seen_last_success_epoch" -eq 1 ] || ab_boot_die "missing LAST_SUCCESS_EPOCH in $state_file"

    case "$AB_BOOT_SUCCESS" in
        0|1)
            ;;
        *)
            ab_boot_die "invalid BOOT_SUCCESS in $state_file: $AB_BOOT_SUCCESS"
            ;;
    esac

    case "$AB_LAST_BOOT_ID" in
        ''|*[!0-9a-f-]*)
            [ -z "$AB_LAST_BOOT_ID" ] || ab_boot_die "invalid LAST_BOOT_ID in $state_file: $AB_LAST_BOOT_ID"
            ;;
    esac

    case "$AB_LAST_SUCCESS_EPOCH" in
        ''|*[!0-9]*)
            [ -z "$AB_LAST_SUCCESS_EPOCH" ] || ab_boot_die "invalid LAST_SUCCESS_EPOCH in $state_file: $AB_LAST_SUCCESS_EPOCH"
            ;;
    esac
}

ab_boot_current_boot_confirmed() {
    slot="$1"
    ab_boot_read_state "$slot"
    current_boot_id=$(ab_boot_current_boot_id)

    if [ "$AB_BOOT_SUCCESS" = 1 ] && [ "$AB_LAST_BOOT_ID" = "$current_boot_id" ]; then
        return 0
    fi

    return 1
}
