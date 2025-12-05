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
	rm -r "$BUILD_DIR" || true
	rm -r "$HOME_DIR/logs/"* || true
	rm -r "$HOME_DIR/tmp" || true
	rm -r "$HOME_DIR/securerd-init" || true
	rm -r "/tmp/uuid" || true
	rm "$HOME_DIR/initrd-menu/custom-scripts/functions.sh" || true
        rm "$HOME_DIR/config/includes.chroot/usr/local/sbin/luks-detect.sh" || true
	echo "Done"
}

build_img(){
     #
     # We use the iso to build a disk image
     #
     ISO_PATH="$HOME_DIR/Yersinia-amd64.hybrid.iso"
     IMG_PATH="$HOME_DIR/Yersinia.img"
     SECOND_PART_SIZE=1
     BUFFER_SIZE=10
     echo "Building image from ISO"
     # Calculate ISO size in MB (rounded up)
	ISO_SIZE_BYTES=$(stat -c%s "$ISO_PATH")
	ISO_SIZE_MB=$(( (ISO_SIZE_BYTES + 1024*1024 - 1) / (1024*1024) ))
	FIRST_PART_SIZE=$(( ISO_SIZE_MB + BUFFER_SIZE ))

	echo "ISO size: ${ISO_SIZE_MB} MB, first partition will be ${FIRST_PART_SIZE} MB" > "$HOME_DIR/logs/build_img.log"
	# Create empty image file
	IMG_SIZE_MB=$(( FIRST_PART_SIZE + SECOND_PART_SIZE + 5 ))
	echo "Creating empty image file of $IMG_SIZE_MB MB..." >> "$HOME_DIR/logs/build_img.log"
	dd if=/dev/zero of="$IMG_PATH" bs=1M count=$IMG_SIZE_MB status=progress >> "$HOME_DIR/logs/build_img.log"
	loopdev=$(losetup --show -fP "$IMG_PATH")
	echo "Loop device created: $loopdev">> "$HOME_DIR/logs/build_img.log"
        SECOND_PART_START=$FIRST_PART_SIZE
        SECOND_PART_END=$((FIRST_PART_SIZE + SECOND_PART_SIZE))
	# Create GPT partition table
	parted -s "$loopdev" mklabel gpt >> "$HOME_DIR/logs/build_img.log"

	# Create partitions
	parted -s "$loopdev" mkpart primary 1MiB "${FIRST_PART_SIZE}MiB" >> "$HOME_DIR/logs/build_img.log"
	parted -s "$loopdev" mkpart primary "${SECOND_PART_START}MiB" "${SECOND_PART_END}MiB" >> "$HOME_DIR/logs/build_img.log"

	# Name partitions
	parted -s "$loopdev" name 1 ISO >> "$HOME_DIR/logs/build_img.log"
	parted -s "$loopdev" name 2 extended-data >> "$HOME_DIR/logs/build_img.log"

	# Refresh partition table
	partprobe "$loopdev" >> "$HOME_DIR/logs/build_img.log"

	# Write ISO to first partition
	echo "Writing ISO to ${loopdev}p1..." >> "$HOME_DIR/logs/build_img.log"
	dd if="$ISO_PATH" of="${loopdev}p1" bs=4M conv=fsync >> "$HOME_DIR/logs/build_img.log" 2>&1
	sgdisk --partition-guid=2:$PART_2_UUID "$loopdev" >> "$HOME_DIR/logs/build_img.log"
	# Detach loop device
	losetup -d "$loopdev" >> "$HOME_DIR/logs/build_img.log"

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
        #build_initramfs
        ;;
    build)
        build_chroot
        #build_initramfs
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

