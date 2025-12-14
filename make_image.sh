#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Must be run as root"
    exit 1
fi

# Load the config
[ -f ./make_image.cfg ] || { echo "Config file not found!"; exit 1; }
. ./make_image.cfg

HOME_DIR=$(pwd)
CHROOT="$HOME_DIR/chroot"
BUILD_DIR="$HOME_DIR/initramfs_mini"
LOG_PATH="$HOME_DIR/logs"
LISTS_SRC="$HOME_DIR/GhostDisk/lists"
LISTS_DST="$HOME_DIR/config/package-lists"

mkdir -p "$LOG_PATH"

#
# If the user is using a JCOP4 Smart card, lets make sure it is in the system and we can see it
# As well as validate we have everything we need and it is all setup correctly
#
if [[ "${KEY_STORE,,}" =~ jcop4 ]] && [[ ${1,,} == "build" ]]; then
     if [ ! -d "$HOME_DIR/gpg_home" ] || [ ! -f "$HOME_DIR/gpg_home/public-key.asc" ]; then
       echo "gpg_home does not exist, it must exist and contain your public key, with the filename public-key.asc, for jcop4 to work"
       exit 1
     else
       chown -R 0:0 gpg_home > "$LOG_PATH/gpg.log"
       chmod 700 gpg_home >> "$LOG_PATH/gpg.log"
       chmod 600 gpg_home/public-key.asc >> "$LOG_PATH/gpg.log"
       	mkdir -p "$HOME_DIR/gpg" >> "$LOG_PATH/gpg.log"
	chmod 700 "$HOME_DIR/gpg" >> "$LOG_PATH/gpg.log"
	export GNUPGHOME="$HOME_DIR/gpg" >> "$LOG_PATH/gpg.log"
	echo "disable-ccid" > "$GNUPGHOME/scdaemon.conf"
	echo "pcsc-shared" >> "$GNUPGHOME/scdaemon.conf"
	echo "default-cache-ttl 300" > "$GNUPGHOME/gpg-agent.conf"
	echo "max-cache-ttl 600" >> "$GNUPGHOME/gpg-agent.conf"
	echo "pinentry-program /bin/pinentry-tty" >> "$GNUPGHOME/gpg-agent.conf"
	gpgconf --kill all >> "$LOG_PATH/gpg.log" 2>&1
	gpgconf --launch gpg-agent >> "$LOG_PATH/gpg.log" 2>&1
        gpg --import "$HOME_DIR/gpg_home/public-key.asc" >> "$LOG_PATH/gpg.log" 2>&1
	if [[ "${VALIDATION,,}" =~ signature ]]; then
	until gpg --card-status 2>&1 | grep -q "Application ID"; do
	    echo "Smartcard not detected, please insert it and press Enter..."
	    read -p "" dummy
	done
	echo "Smartcard detected, proceeding..."
	output=$(gpg --card-status --with-colons 2>/dev/null)
	# Extract the forcepin value
	forcepin_value=$(echo "$output" | grep '^forcepin:' | cut -d: -f2)
	# Check if the value exists and act accordingly
	if [[ -z "$forcepin_value" ]]; then
	    echo "Could not find 'forcepin' status on the card."
	elif [[ "$forcepin_value" == "1" ]]; then
	    echo "Warning: Signature Pin is set to force. You should change it to not force."
	    echo "Otherwise it will ask you to enter your pin for every signature"
	    echo "This becomes an issue when signing 10+ files in the boot chain"
	    read -r -p "Press Enter to continue or CTRL-C to stop..."
	else
	    echo "Signature Pin set to not force"
	fi
	fi
    fi
fi

generate_uuid() {
    # Generates a random UUID
    if command -v uuidgen >/dev/null 2>&1; then
        # If uuidgen is installed
        uuidgen | tr '[:lower:]' '[:upper:]'
    elif [ -r /proc/sys/kernel/random/uuid ]; then
        # Fallback for Linux systems
        cat /proc/sys/kernel/random/uuid | tr '[:lower:]' '[:upper:]'
    else
        # Pure bash fallback (less secure, but works)
        echo "$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1)-$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 4 | head -n 1)-4$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 3 | head -n 1)-$(printf '%x' $(( (RANDOM % 4) + 8 )))$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 3 | head -n 1)-$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 12 | head -n 1 | tr '[:lower:]' '[:upper:]' )"
    fi
}

build_chroot() {
    echo "Building chroot for initramfs"
    mkdir "$HOME_DIR/tmp" || true  >> "$LOG_PATH/build_chroot.log" 2>&1
    cd "$HOME_DIR/tmp" >> "$LOG_PATH/build_chroot.log" 2>&1
    lb clean >> "$LOG_PATH/build_chroot.log" 2>&1
    lb config >> "$LOG_PATH/build_chroot.log" 2>&1
    files=($HOME_DIR/securerd/lists/*.chroot)
	    [ ${#files[@]} -gt 0 ] && cp "${files[@]}" "$HOME_DIR/tmp/config/package-lists/"
    files=($HOME_DIR/initrd-menu/lists/*.chroot)
	    [ ${#files[@]} -gt 0 ] && cp "${files[@]}" "$HOME_DIR/tmp/config/package-lists/"
    lb bootstrap >> "$LOG_PATH/build_chroot.log" 2>&1
    lb chroot >> "$LOG_PATH/build_chroot.log" 2>&1
}

build_iso() {
    echo "Building final ISO"
    # Ensure base + X11 are present and up to date
    for f in base.list.chroot X11.list.chroot; do
        if [ ! -f "$LISTS_DST/$f" ] || [ "$LISTS_SRC/$f" -nt "$LISTS_DST/$f" ]; then
            cp -f "$LISTS_SRC/$f" "$LISTS_DST/" >> "$LOG_PATH/build_iso.log" 2>&1
        fi
    done
    #
    # Generate random UUID to identify the persistent storage later
    #
    PART_2_UUID="$(generate_uuid)"
    echo "PART_2_UUID=$PART_2_UUID" > /tmp/uuid
 #
 # Add the uuid to the luks-detect script
 #
 sed "s/@@UUID@@/$PART_2_UUID/" $HOME_DIR/GhostDisk/custom-scripts/luks-detect.sh.template > $HOME_DIR/config/includes.chroot/usr/local/sbin/luks-detect.sh

#
# Enable auto-rotate if it is set true in the config
#
{
    if [ "$AUTO_ROTATE" = "true" ]; then
        echo "Enabling auto-rotate…"

        cp "$HOME_DIR/GhostDisk/auto-rotate/rotate.list.chroot" \
           "$HOME_DIR/config/package-lists/rotate.list.chroot"

        cp "$HOME_DIR/GhostDisk/auto-rotate/auto-rotate.desktop" \
           "$HOME_DIR/config/includes.chroot/etc/xdg/autostart/auto-rotate.desktop"

        cp "$HOME_DIR/GhostDisk/auto-rotate/auto-rotate.sh" \
           "$HOME_DIR/config/includes.chroot/usr/local/bin/auto-rotate.sh"
    else
        echo "Disabling auto-rotate…"

        # Only remove if the file exists
        [ -f "$HOME_DIR/config/package-lists/rotate.list.chroot" ] && \
            rm "$HOME_DIR/config/package-lists/rotate.list.chroot"

        [ -f "$HOME_DIR/config/includes.chroot/etc/xdg/autostart/auto-rotate.desktop" ] && \
            rm "$HOME_DIR/config/includes.chroot/etc/xdg/autostart/auto-rotate.desktop"

        [ -f "$HOME_DIR/config/includes.chroot/usr/local/bin/auto-rotate.sh" ] && \
            rm "$HOME_DIR/config/includes.chroot/usr/local/bin/auto-rotate.sh"
    fi

} >> "$LOG_PATH/build_iso.log" 2>&1

    # Desktop-specific handling
    case "$DESKTOP_ENV" in
        lxqt)
            # Remove XFCE lists if present
            rm -f \
                "$LISTS_DST/desktop-xfce.list.chroot" \
                "$LISTS_DST/myapps-xfce.list.chroot" >> "$LOG_PATH/build_iso.log" 2>&1
    
            # Copy LXQt lists (if missing or outdated)
            for f in desktop-lxqt.list.chroot myapps-lxqt.list.chroot; do
                if [ ! -f "$LISTS_DST/$f" ] || [ "$LISTS_SRC/$f" -nt "$LISTS_DST/$f" ]; then
                    cp -f "$LISTS_SRC/$f" "$LISTS_DST/" >> "$LOG_PATH/build_iso.log" 2>&1
                fi
            done
            ;;
  
        xfce)
            # Remove LXQt lists if present
            rm -f \
                "$LISTS_DST/desktop-lxqt.list.chroot" \
                "$LISTS_DST/myapps-lxqt.list.chroot" >> "$LOG_PATH/build_iso.log" 2>&1
    
            # Copy XFCE lists (if missing or outdated)
            for f in desktop-xfce.list.chroot myapps-xfce.list.chroot; do
                if [ ! -f "$LISTS_DST/$f" ] || [ "$LISTS_SRC/$f" -nt "$LISTS_DST/$f" ]; then
                    cp -f "$LISTS_SRC/$f" "$LISTS_DST/" >> "$LOG_PATH/build_iso.log" 2>&1
                fi
            done
            ;;
    esac    
    cd $HOME_DIR
    lb clean > "$LOG_PATH/build_iso.log" 2>&1
    lb config >> "$LOG_PATH/build_iso.log" 2>&1
    # Update user + password in hook
    sed -i \
        -e "s/^USERNAME=.*/USERNAME=\"$LIVE_USER\"/" \
        -e "s/^PASSWORD=.*/PASSWORD=\"$LIVE_PASSWORD\"/" \
        $HOME_DIR/config/hooks/normal/1001-create-user.hook.chroot >> "$LOG_PATH/build_iso.log" 2>&1
    # Build the iso image
    lb build >> "$LOG_PATH/build_iso.log" 2>&1
}

clean() {
    echo "Cleaning environment"

    lb clean --purge

    [ -d "$BUILD_DIR" ] && rm -r "$BUILD_DIR"
    [ -d "$HOME_DIR/logs" ] && rm -r "$HOME_DIR/logs/"*
    [ -d "$HOME_DIR/tmp" ] && rm -r "$HOME_DIR/tmp"
    [ -d "$HOME_DIR/securerd-init" ] && rm -r "$HOME_DIR/securerd-init"
    [ -d "/tmp/uuid" ] && rm -r "/tmp/uuid"
    [ -d "$HOME_DIR/openssl" ] && rm -r "$HOME_DIR/openssl"
    [ -d "$HOME_DIR/gpg" ] && rm -r "$HOME_DIR/gpg"
    [ -d "$HOME_DIR/mnt" ] && rm -r "$HOME_DIR/gpg"
    [ -f "$HOME_DIR/initrd-menu/custom-scripts/functions.sh" ] && rm "$HOME_DIR/initrd-menu/custom-scripts/functions.sh"
    [ -f "$HOME_DIR/config/includes.chroot/usr/local/sbin/luks-detect.sh" ] && rm "$HOME_DIR/config/includes.chroot/usr/local/sbin/luks-detect.sh"

    echo "Done"
}

build_img() {
    #
    # Build a bootable disk image from live-build binary output
    # 3-partition layout: 1=BIOS-boot, 2=Boot/Live (FAT32), 3=extended-data
    #
    #
    BINARY_DIR="$HOME_DIR/binary"
    IMG_PATH="$HOME_DIR/Yersinia.img"
    SECOND_PART_SIZE=1  # MB for extended-data
    LOG_FILE="$HOME_DIR/logs/build_img.log"
    
    echo "Building disk image from live-build binary..." | tee -a "$LOG_FILE"
    
    # Verify binary directory exists
    if [ ! -d "$BINARY_DIR/live" ]; then
        echo "ERROR: '$BINARY_DIR/live' not found - run live-build first!" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # --- 1. Calculate required size ---
    LIVE_SIZE=$(du -sb "$BINARY_DIR/live" | awk '{print $1}')
    LIVE_SIZE_MB=$(( (LIVE_SIZE + 1024*1024 - 1) / (1024*1024) ))
    
    BOOT_SIZE_MB=$(( LIVE_SIZE_MB + 100 ))
    TOTAL_SIZE_MB=$(( BOOT_SIZE_MB + SECOND_PART_SIZE + 10 ))
    
    echo "Live system: ${LIVE_SIZE_MB} MB, Total image: ${TOTAL_SIZE_MB} MB"  >> "$LOG_FILE" 2>&1
    
    # --- 2. Create empty image ---
    echo "Creating empty disk image..." >> "$LOG_FILE" 2>&1
    dd if=/dev/zero of="$IMG_PATH" bs=1M count=$TOTAL_SIZE_MB >> "$LOG_FILE" 2>&1
    
    # --- 3. Create GPT partitions ---
    echo "Creating GPT partitions..."  >> "$LOG_FILE" 2>&1
    
    loopdev=$(losetup --show -fP "$IMG_PATH")
    echo "Loop device: $loopdev" >>"$LOG_FILE"
 
    # Partition 1: BIOS boot (2 MiB)
    # 2048 sectors start, 4095 sectors end (~2 MiB, 512B sectors)
    sgdisk -n1:2048:4095 -t1:EF02 -c1:"BIOS" "$loopdev" >> "$LOG_FILE" 2>&1

    # Partition 2: Boot/Live system (FAT32 for UEFI + live files)
    # Start: 4096 sectors (approx 2 MiB), End: BOOT_SIZE_MB in sectors
    BOOT_END_SECTOR=$((BOOT_SIZE_MB * 2048))  # 1 MiB = 2048 sectors
    sgdisk -n2:4096:$BOOT_END_SECTOR -t2:EF00 -c2:"BOOT" "$loopdev" >> "$LOG_FILE" 2>&1

    # --- 3. Create partition 3: Extended data ---
    echo "Creating extended-data partition (partition 3) with GUID $PART_2_UUID..." >> "$LOG_FILE"
    sgdisk -n3:0:0 -t3:8300 -c3:"extended-data" -u3:$PART_2_UUID "$loopdev" >> "$LOG_FILE" 2>&1

    # Make sure kernel sees updated GPT    
    partprobe "$loopdev"
    sleep 2
    
    # --- 4. Format boot partition ---
    echo "Formatting boot partition..." >> "$LOG_FILE"
    mkfs.vfat -F32 -n YERSINIA "${loopdev}p2" >> "$LOG_FILE" 2>&1
    
    # --- 5. Mount boot partition ---
    BOOT_MOUNT="/tmp/boot_$$"
    mkdir -p "$BOOT_MOUNT"
    mount "${loopdev}p2" "$BOOT_MOUNT"
    
    # --- 6. Copy live system files (no hardlinks for FAT32) ---
    echo "Copying live system..." >> "$LOG_FILE"
    mkdir -p "$BOOT_MOUNT/live"
    # Use rsync with -L to follow symlinks instead of copying them
    rsync -rL "$BINARY_DIR/live/" "$BOOT_MOUNT/live/" >> "$LOG_FILE" 2>&1
    
    # --- 7. Setup EFI directory structure ---
    echo "Setting up EFI boot..." >> "$LOG_FILE"
    mkdir -p "$BOOT_MOUNT/EFI/BOOT"
    rsync -rL "$BINARY_DIR/EFI/boot/" "$BOOT_MOUNT/EFI/BOOT/" >> "$LOG_FILE" 2>&1
    
    # --- 8. Install GRUB for BIOS ---
    echo "Installing GRUB for BIOS..." >> "$LOG_FILE" 2>&1
    grub-install --target=i386-pc \
                 --boot-directory="$BOOT_MOUNT/boot" \
                 "$loopdev" >> "$LOG_FILE" 2>&1 </dev/null
    
    # --- 9. Install GRUB for UEFI ---
    echo "Installing GRUB for UEFI..." >> "$LOG_FILE" 2>&1
    grub-install --target=x86_64-efi \
                 --efi-directory="$BOOT_MOUNT" \
                 --boot-directory="$BOOT_MOUNT/boot" \
                 --removable --recheck >> "$LOG_FILE" 2>&1 </dev/null
    
    # --- 10. Copy GRUB config ---
    echo "Copying GRUB configuration..." >> "$LOG_FILE" 2>&1
    mkdir -p "$BOOT_MOUNT/boot/grub"
    rsync -r "$BINARY_DIR/boot/grub/" "$BOOT_MOUNT/boot/grub/" >> "$LOG_FILE" 2>&1 
    
    # Verify grub.cfg exists
    if [ ! -f "$BOOT_MOUNT/boot/grub/grub.cfg" ]; then
        echo "ERROR: grub.cfg not found after copy!" | tee -a "$LOG_FILE"
        find "$BOOT_MOUNT/boot/grub" -type f | tee -a "$LOG_FILE"
        umount "$BOOT_MOUNT"
        losetup -d "$loopdev"
        exit 1
    fi
    
    # --- 11. Cleanup ---
    echo "Syncing and unmounting..."  >> "$LOG_FILE" 2>&1
    sync
    umount "$BOOT_MOUNT"
    rmdir "$BOOT_MOUNT"
    losetup -d "$loopdev" >> "$LOG_FILE" 2>&1
    
    echo "Disk image build complete: $IMG_PATH" | tee -a "$LOG_FILE"
}


usage() {
    echo "Usage: $0 {chroot|initramfs|build|clean}"
    exit 1
}

case "$1" in
    chroot)
        build_chroot
        ;;
    initramfs)
	if [ ! -d "$HOME_DIR/tmp/chroot" ]; then
           echo "Chroot not found, building..."
           build_chroot
        fi
        ;;
    build)
        build_chroot
        build_iso
	build_img
        ;;
    clean)
       clean
       ;;
    *)
        usage
        ;;
esac

