# 🐧 Artix Linux Installation Guide

> **Personal guide** for manually installing Artix Linux (runit) with:
> `btrfs subvolumes` · `LUKS encryption` · `LVM` · `swapfile` · `zram`

---

# 📖 Table of Contents

1. [Network](#-chapter-1--network)
2. [Setting Up the Drive](#-chapter-2--setting-up-the-drive)
    - [Partitioning](#partitioning)
    - [Encryption](#encryption)
    - [Formatting](#formatting)
    - [LVM Setup](#lvm-setup)
    - [Btrfs Subvolumes](#btrfs-subvolumes)
    - [Mounting](#mounting)
3. [Base Install](#-chapter-3--base-install)
4. [Swap & Zram](#-chapter-4--swap--zram)
5. [Time Zone & Locale](#-chapter-5--time-zone--locale)
6. [Hostname & Hosts](#-chapter-6--hostname--hosts)
7. [User Setup](#-chapter-7--user-setup)
8. [Services](#-chapter-8--services)
9. [DNS (Optional)](#-chapter-9--dns-optional)
10. [GRUB & Initramfs](#-chapter-10--grub--initramfs)

---

# 🌐 Chapter 1 — Network

Use `iwctl` for a **wireless** connection. If you are on **ethernet**, skip this chapter entirely.

```bash
iwctl station list                        # 1. Find your wireless station name
iwctl station wlan0 scan                  # 2. Scan for nearby networks
iwctl station wlan0 get-networks          # 3. List discovered networks
iwctl station wlan0 connect <ssid>        # 4. Connect (replace <ssid> with your network name)
ping -c 3 artixlinux.org                  # 5. Verify connectivity
```

---

# 💽 Chapter 2 — Setting Up the Drive

Use `lsblk -f` to list all available drives and identify your target disk.  
The examples in this guide use **`/dev/nvme0n1`** — replace this with your actual device path.

## Partitioning

Use `cfdisk /dev/nvme0n1` to interactively partition the drive. Create the following layout:

| Block            | Type             | Size      | Purpose                      |
| ---------------- | ---------------- | --------- | ---------------------------- |
| `/dev/nvme0n1p1` | EFI System       | `1 GiB`   | EFI boot partition           |
| `/dev/nvme0n1p2` | Linux filesystem | `512 MiB` | Unencrypted `/boot`          |
| `/dev/nvme0n1p3` | Linux filesystem | Remaining | LUKS-encrypted LVM container |

> ℹ️ **"Remaining"** means all leftover disk space after the first two partitions.

---

## Encryption

Encrypt the third partition with LUKS:

```bash
cryptsetup luksFormat /dev/nvme0n1p3
```

You will be prompted to set and confirm a passphrase. Then open (unlock) the encrypted container:

```bash
cryptsetup open /dev/nvme0n1p3 cryptlvm
```

> 📝 `cryptlvm` is the mapped device name. You may choose any name you prefer — just use it **consistently** throughout the rest of this guide wherever `cryptlvm` appears.

---

## Formatting

Format and label the non-LVM partitions:

```bash
mkfs.fat -F32 /dev/nvme0n1p1             # Format EFI partition as FAT32
fatlabel /dev/nvme0n1p1 EFI              # Label it "EFI"
mkfs.ext4 -L boot /dev/nvme0n1p2         # Format boot partition as ext4, label "boot"
```

---

## LVM Setup

Create the Physical Volume, Volume Group, and Logical Volumes inside the unlocked LUKS container:

```bash
pvcreate /dev/mapper/cryptlvm           # Initialize physical volume
vgcreate vg0 /dev/mapper/cryptlvm       # Create volume group named "vg0"
lvcreate -L 50G  -n arch-root vg0       # Root logical volume (adjust size as needed)
lvcreate -l 100%FREE -n arch-home vg0   # Home logical volume (uses all remaining space)
```

Format the logical volumes:

```bash
mkfs.btrfs -L root /dev/vg0/arch-root   # Root as Btrfs
mkfs.ext4  -L home /dev/vg0/arch-home   # Home as ext4
```

---

## Btrfs Subvolumes

Mount `arch-root` temporarily to create the subvolume layout:

```bash
mount /dev/vg0/arch-root /mnt
```

Create the following subvolumes:

```bash
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/tmp
btrfs subvolume create /mnt/var_log
btrfs subvolume create /mnt/var_cache
btrfs subvolume create /mnt/var_tmp
btrfs subvolume create /mnt/docker
btrfs subvolume create /mnt/libvirt
btrfs subvolume create /mnt/swap
btrfs subvolume create /mnt/opt
btrfs subvolume create /mnt/snapshots
```

Then unmount:

```bash
umount /mnt
```

> ⚠️ Yes, the command is `umount`, not `unmount` — the missing **'n'** is intentional.

---

## Mounting

Mount each subvolume to its target path. The same set of mount options is applied uniformly to all subvolumes for consistency:

| Option            | Effect                                       |
| ----------------- | -------------------------------------------- |
| `noatime`         | Disables access time tracking (performance)  |
| `compress=zstd:3` | Transparent Zstd compression at level 3      |
| `ssd`             | Enables SSD-optimized I/O heuristics         |
| `discard=async`   | Asynchronous TRIM support for SSDs           |
| `space_cache=v2`  | Uses the v2 free space cache (more reliable) |
| `subvol=<name>`   | Selects which subvolume to mount             |

```bash
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=root      /dev/vg0/arch-root /mnt
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=tmp       /dev/vg0/arch-root /mnt/tmp
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=var_log   /dev/vg0/arch-root /mnt/var/log
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=var_cache /dev/vg0/arch-root /mnt/var/cache
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=var_tmp   /dev/vg0/arch-root /mnt/var/tmp
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=docker    /dev/vg0/arch-root /mnt/var/lib/docker
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=libvirt   /dev/vg0/arch-root /mnt/var/lib/libvirt
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=swap      /dev/vg0/arch-root /mnt/swap
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=opt       /dev/vg0/arch-root /mnt/opt
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=snapshots /dev/vg0/arch-root /mnt/.snapshots
```

Mount the remaining partitions:

```bash
mount --mkdir /dev/nvme0n1p2       /mnt/boot       # Unencrypted boot
mount --mkdir /dev/nvme0n1p1       /mnt/boot/efi   # EFI partition (must be inside /boot)
mount --mkdir /dev/vg0/arch-home   /mnt/home       # Home logical volume
```

---

# 📦 Chapter 3 — Base Install

Install the base system and essential packages using `basestrap`:

```bash
basestrap /mnt \
  base linux-zen linux-zen-headers base-devel linux-firmware \
  git efibootmgr grub iwd-runit \
  btrfs-progs vim cryptsetup-runit lvm2-runit zramen
```

> 📝 **Artix-specific packages:**
>
> - `iwd-runit`, `lvm2-runit`, `cryptsetup-runit` — runit service definitions for each daemon
> - `zramen-runit` — runit-compatible zram management

Generate the filesystem table and enter the new system:

```bash
fstabgen -U /mnt >> /mnt/etc/fstab      # Generate fstab using UUIDs
artix-chroot /mnt                       # Chroot into the new installation
```

> 📝 Artix uses `artix-chroot` instead of `arch-chroot`. All commands from this point forward are executed **inside the chroot** unless stated otherwise.

---

# 💾 Chapter 4 — Swap & Zram

## Btrfs Swapfile

> ⚠️ **Order matters:** Copy-on-Write (CoW) must be disabled on the swap directory **before** creating the swapfile, otherwise the swapfile will be invalid.

```bash
chattr +C /swap                                                     # 1. Disable CoW on the swap directory first
btrfs filesystem mkswapfile --size 8G --uuid clear /swap/swapfile  # 2. Create the swapfile (adjust size as needed)
chattr +C /swap/swapfile                                            # 3. Disable CoW on the swapfile itself
```

Add the swapfile entry to `/etc/fstab`:

```bash
# /etc/fstab — append this line:
/swap/swapfile  none  swap  default  0  0
```

## Zram

`zram-generator` is a systemd-only tool and is **not used on Artix**. Instead, `zramen` (already installed in Chapter 3) provides runit-native zram management.

Edit `/etc/zramen.conf` and set the following values:

```bash
ZRAM_SIZE=50                # percentage of RAM (equivalent to ram / 2)
ZRAM_COMP_ALGORITHM=zstd
ZRAM_PRIORITY=100           # Swap priority (higher = preferred over swapfile)
```

> 💡 To allocate 65% of RAM instead of 50%, change `ZRAMEN_SIZE=50` to `ZRAMEN_SIZE=65`.
>
> A higher `ZRAM_PRIORITY` value means zram is preferred over the swapfile when the kernel needs to swap.

The service is enabled in Chapter 8.

---

# 🕐 Chapter 5 — Time Zone & Locale

## Time Zone

```bash
ln -sf /usr/share/zoneinfo/<Continent>/<City> /etc/localtime    # e.g. Europe/London or America/New_York
hwclock --systohc                                                 # Sync hardware clock to system time
```

## Locale

Open `/etc/locale.gen` in your editor and **uncomment** the line for your desired locale.  
For US English:

```
en_US.UTF-8 UTF-8
```

Then generate the locale:

```bash
locale-gen
```

Set the locale and console keymap by creating/editing these files:

```bash
# /etc/locale.conf
LANG=en_US.UTF-8
```

```bash
# /etc/vconsole.conf
KEYMAP=us
```

---

# 🖥️ Chapter 6 — Hostname & Hosts

Set the machine's hostname:

```bash
# /etc/hostname
artix
```

Configure the local hosts file:

```bash
# /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   artix.localdomain  artix
```

> Also ensure the hostname entries in `/etc/hosts` match whatever you set in `/etc/hostname`.

---

# 👤 Chapter 7 — User Setup

Set the **root** password first, then create your personal user account:

```bash
passwd                                   # Set root password
useradd -mG wheel -s /bin/bash <name>   # Create user and add to the wheel group
passwd <name>                            # Set the user's password
```

Grant `wheel` group members `sudo` access by editing the sudoers file safely:

```bash
EDITOR=vim visudo
```

Find and **uncomment** the following line:

```
%wheel ALL=(ALL:ALL) ALL
```

---

# ⚙️ Chapter 8 — Services

On Artix with dinit, services are enabled using dinitctl.

```bash
dinitctl enable <service>
```

Enable the required services:

```bash
ln -s /etc/runit/sv/iwd        /etc/runit/runsvdir/default/   # Wireless networking
ln -s /etc/runit/sv/zramen     /etc/runit/runsvdir/default/   # Zram swap
```

> 📝 `iwd` (iNet wireless daemon) handles Wi-Fi. Its configuration below enables built-in DHCP and points name resolution to `openresolv` (configured in Chapter 9).

Create a file at `/etc/iwd/main.conf` and add the following:

```ini
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=resolvconf
```

---

# 🌍 Chapter 9 — DNS _(Optional)_

`systemd-resolved` does not exist on Artix. This chapter uses `openresolv` with a static configuration instead.

Install `openresolv`:

```bash
pacman -S openresolv
```

Create `/etc/resolvconf.conf` with your preferred DNS servers (AdGuard DNS in this example):

```ini
# /etc/resolvconf.conf
name_servers="94.140.14.14 94.140.15.15"
name_servers_append="1.1.1.1 1.0.0.1"
```

Apply the configuration:

```bash
resolvconf -u
```

> 📝 The `NameResolvingService=resolvconf` line in `/etc/iwd/main.conf` (set in Chapter 8) ensures `iwd` hands DNS results to `openresolv` automatically on connection.

---

# 🔐 Chapter 10 — GRUB & Initramfs

## Retrieving UUIDs

You need to obtain the UUID of the LUKS container for the GRUB configuration:

```bash
blkid -o value -s UUID /dev/nvme0n1p3    # Copy this — it's the LUKS container UUID
```

## Configuring GRUB

Open `/etc/default/grub` in your editor. Locate the `GRUB_CMDLINE_LINUX_DEFAULT` line and add the kernel parameters, replacing `<LUKS_UUID>` with the UUID from above:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="... rd.luks.name=<LUKS_UUID>=cryptlvm root=/dev/vg0/arch-root"
```

> ⚠️ **Do not replace** any existing parameters on that line — only **append** to them.  
> The mapped device name (`cryptlvm`) must match what you used in `cryptsetup open` in Chapter 2.

Also uncomment this line to enable GRUB's LUKS support:

```
GRUB_ENABLE_CRYPTODISK=y
```

## Installing GRUB

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## Configuring Initramfs

Open `/etc/mkinitcpio.conf` and make the following changes:

**1. Add the btrfs module:**

```bash
MODULES=(btrfs)
```

**2. Add `sd-encrypt` and `lvm2` to the hooks** — they must appear **between** `block` and `filesystems`:

```bash
HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block sd-encrypt lvm2 filesystems fsck)
```

> ℹ️ The full HOOKS line is shown above for clarity. `sd-encrypt` handles LUKS unlocking at the initramfs stage — **before** runit takes over — so it remains valid here despite Artix not using systemd as its init. `lvm2` activates the volume groups. Their position relative to `block` and `filesystems` is **required**.

Regenerate the initramfs:

```bash
mkinitcpio -P
```

## Finishing Up

Exit the chroot and reboot:

```bash
exit
reboot
```

> 🎉 If everything is configured correctly, GRUB will prompt for your LUKS passphrase on boot, then hand off to the Artix runit system. Welcome to your new install!
