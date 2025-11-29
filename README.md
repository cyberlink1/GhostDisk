# GhostDisk
A live-build framework for creating amnestic bootable images. Features a custom initramfs with a TUI for managing LUKS encrypted storage and additional disks. Focused on security, privacy, and easy customization of apps and tools.

## Overview

This project provides a streamlined framework for building your own amnestic (memory-wiping) Linux system with encrypted persistent storage. Rather than being locked into a pre-built image, you have full control over packages, desktop environment, and security settings while maintaining a minimal attack surface.

Built by a retired Unix/Linux engineer with 35+ years of experience in administration, engineering, security audits, and penetration testing.

## Why This Project?

Privacy-focused bootable Linux distributions like Tails are excellent, but they come with limitations:
- Difficult to customize for specific needs
- Bloated with apps you may not want or need
- Larger vulnerability footprint due to unnecessary packages
- Bound to the project's release schedule for updates

This project takes a different approach: it's not an image, it's a collection of live-build configurations with custom scripting. The entire framework is under 2MB, and it generates fresh images using the latest Debian packages each time you build.

## Features

- **Customizable**: Choose your desktop (LXQt or XFCE), packages, and applications
- **Minimal footprint**: currently ~1.4G
- **Encrypted persistent storage**: Manage LUKS partitions with custom menu system
- **Up-to-date packages**: Pulls latest packages from Debian repositories on each build
- **Auto-rotate support**: Optional screen rotation for convertible laptops/tablets
- **Privacy-focused**: Includes Tor Browser and Signal Desktop by default

## Quick Start

1. Clone this repository
2. Edit `make_image.cfg` to set your username, passwords, and preferences
3. Run: `sudo ./make_image.sh build`

The script handles everything: downloads latest packages, builds the system, installs your chosen desktop and applications, and generates a bootable image ready for USB drive or SD card.

## Build Commands

```bash
sudo ./make_image.sh [option]
```

Options:
- `chroot` - Build only the chroot environment for initramfs-mini
- `initramfs` - Build only the initramfs-mini image
- `build` - Build the complete ISO/image
- `clean` - Clean the environment back to default

## Directory Structure

- **`auto-rotate/`** - Screen rotation support for convertible laptops
- **`create_links/`** - Scripts for persistent storage on encrypted drive (see README.txt inside)
- **`custom-scripts/`** - Custom scripts for the initramfs-mini
- **`pwcheck/`** - Password verification program for menu login
- **`logs/`** - Build logs (chroot, initramfs, and ISO builds)
- **`lists/`** - Package lists for building the image
- **`docs/`** - Detailed documentation on system internals

## Configuration

### make_image.cfg

Configure basic settings:
- Username and password for your user account
- Root password for initramfs-mini
- Desktop environment (lxqt/xfce)
- Auto-rotate screen option (for convertible laptops)

### Package Lists (lists/)

Customize installed packages by editing these files:
- `base.list.chroot` - Base packages for ISO
- `X11.list.chroot` - X11 desktop packages
- `desktop-lxqt.list.chroot` - LXQt desktop packages
- `desktop-xfce.list.chroot` - XFCE desktop packages
- `myapps-lxqt.list.chroot` - LXQt applications
- `myapps-xfce.list.chroot` - XFCE applications
- `initramfs.list.chroot` - Extra packages for initramfs-mini

**Note**: Tor Browser and Signal Desktop are installed via hooks in `config/hooks/normal/` (9023-torbrowser-install.hook.chroot and 9024-signal-install.hook.chroot). Remove these files if you don't want them.

## How It Works

1. **Chroot Build**: Uses live-build to create a small chroot environment with current release packages that are selectivly used to make the initramfs-mini.
2. **Initramfs-mini**: Builds a minimal initramfs (~15MB) using `initramfs_template.txt`
3. **ISO Build**: Creates the full bootable ISO with your chosen desktop and applications
4. **Image Generation**: Generates the final image ready to write to storage

### Build Logs

Logs are created in order during a full build:
1. `build_chroot.log` - Live-build output for initramfs-mini chroot
2. `build_initramfs.log` - Initramfs-mini build and file copying
3. `build_iso.log` - Live-build output for final ISO

## Troubleshooting

**Most common build failure**: Library version mismatches after package updates (e.g., `libsomething.so.3.0.2` becomes `libsomething.so.3.0.3`). Check `logs/build_initramfs.log` for the exact error and update `initramfs_template.txt` accordingly.

**UUID Generation**: The script generates a unique random UUID for the second partition. This is used for partition expansion and mounting encrypted storage - it's not a tracking mechanism.

## Contributing

Feel free to submit issues or pull requests. Documentation improvements are always welcome!
