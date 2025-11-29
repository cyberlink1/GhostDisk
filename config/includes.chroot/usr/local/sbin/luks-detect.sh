#!/bin/bash
# Scan for USB device containing a partition with a target UUID and configure LUKS mounting

# UUID to match (set by make_image.sh)
TARGET_UUID="82817F06-C1AD-4C5C-BBCE-399981FAF986"

configure_device() {
    local iso_dev="$1"
    local data_dev="$2"

    local user
    user=$(ls /home | head -n1)
    local mountpoint="/home/$user/Encrypted"

    mkdir -p "$mountpoint" || true

    # Add to fstab if not already present
    if ! grep -q "$data_dev" /etc/fstab; then
        echo "/dev/mapper/luksdata $mountpoint ext3 noexec,nofail,sync,users 0 0" >> /etc/fstab
    fi

    # Add to crypttab if not already present
    if ! grep -q "luksdata" /etc/crypttab; then
        local uuid
        uuid=$(blkid -s UUID -o value "$data_dev")
        echo "luksdata UUID=$uuid none luks" >> /etc/crypttab
    fi

    systemctl daemon-reload
}

scan_for_usb_device() {
    local iso_dev=""
    local data_dev=""

    for usb_dev in /sys/block/*; do
        [ -d "$usb_dev" ] || continue
        local dev_name
        dev_name=$(basename "$usb_dev")

        local part1="/dev/${dev_name}1"
        local part2="/dev/${dev_name}2"

        # Both partitions must exist
        [ -e "$part1" ] || continue
        [ -e "$part2" ] || continue

        # Get UUID of partition 2 via sgdisk
        local uuid
        uuid=$(/usr/sbin/sgdisk -i 2 "/dev/${dev_name}" | awk -F': ' '/Partition unique GUID/ {print $2}' | tr -d "'")

        # Compare with target
        if [ "$uuid" = "$TARGET_UUID" ]; then
            iso_dev="$part1"
            data_dev="$part2"
            break
        fi
    done

    [ -n "$iso_dev" ] && [ -n "$data_dev" ] || return 1

    # Return devices
    printf '%s %s\n' "$iso_dev" "$data_dev"
    #printf '%s\n' "$data_dev"
}

main() {
    read -r iso_dev data_dev < <(scan_for_usb_device) || exit 1
    configure_device "$iso_dev" "$data_dev"
}

main

