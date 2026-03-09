# 🐧 Arch Linux Installation Guide

> **Personal guide** for manually installing Arch Linux with:
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
ping -c 3 archlinux.org                   # 5. Verify connectivity
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

Install the base system and essential packages using `pacstrap`:

```bash
pacstrap -K /mnt \
  base linux-zen linux-zen-headers base-devel linux-firmware \
  git efibootmgr grub iwd \
  btrfs-progs vim cryptsetup lvm2 zram-generator
```

Generate the filesystem table and enter the new system:

```bash
genfstab -U /mnt >> /mnt/etc/fstab    # Generate fstab using UUIDs
arch-chroot /mnt                       # Chroot into the new installation
```

> 📝 All commands from this point forward are executed **inside the chroot** unless stated otherwise.

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

Create the zram configuration directory and file:

```bash
mkdir -pv /etc/systemd/zram-generator.conf.d/
touch /etc/systemd/zram-generator.conf.d/zram.conf
```

Add the following content to `/etc/systemd/zram-generator.conf.d/zram.conf`:

```ini
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
```

> 💡 To allocate 65% of RAM instead of 50%, change `ram / 2` to `ram * 0.65`.
>
> A higher `swap-priority` value means zram is preferred over the swapfile when the kernel needs to swap.

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
arch
```

Configure the local hosts file:

```bash
# /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch.localdomain  arch
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

Enable the wireless networking daemon so it starts on boot:

```bash
systemctl enable iwd.service
```

> 📝 `iwd` (iNet wireless daemon) handles Wi-Fi. If you plan to use it alongside `systemd-resolved` for DNS, ensure both are enabled (see Chapter 9).

Create a file at `/etc/iwd/main.conf` and add these:

```bash
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
```

---

# 🌍 Chapter 9 — DNS _(Optional)_

This configures `systemd-resolved` with custom DNS servers (AdGuard DNS in this example).

Edit `/etc/systemd/resolved.conf` and add or uncomment the following under `[Resolve]`:

```ini
# /etc/systemd/resolved.conf
[Resolve]
DNS=94.140.14.14 94.140.15.15
FallbackDNS=1.1.1.1 1.0.0.1
Domains=~.
```

Enable and start the service:

```bash
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable systemd-resolved.service
```

Finally, ensure `/etc/resolv.conf` points to the stub resolver. If it is not already a symlink, create it manually:

```bash
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

---

# 🔐 Chapter 10 — GRUB & Initramfs

## Retrieving UUIDs

You need to obtain the UUIDs for the GRUB configuration — the LUKS container:

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
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block sd-encrypt lvm2 filesystems fsck)
```

> ℹ️ The full HOOKS line is shown above for clarity. `sd-encrypt` handles LUKS unlocking at boot; `lvm2` activates the volume groups. Their position relative to `block` and `filesystems` is **required**.

Regenerate the initramfs:

```bash
mkinitcpio -P
```

## Finishing Up

Exit the chroot and reboot:

```bash
exit
systemctl reboot
```

> 🎉 If everything is configured correctly, GRUB will prompt for your LUKS passphrase on boot, then hand off to the Arch system. Welcome to your new install!
