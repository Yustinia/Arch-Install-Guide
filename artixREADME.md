# Artix Linux Install Guide

> A personal guide for manually installing **Artix Linux** with **dinit**, featuring:
> `btrfs subvolumes` · `swap` · `zram`

---

## Table of Contents

1. [Network](#network)
2. [Drive Setup](#drive-setup)
3. [Base Install](#base-install)
4. [Swap & Zram](#swap--zram)
5. [Users & Locale](#users--locale)
6. [Network Configuration](#network-configuration)
7. [GRUB & initramfs](#grub--initramfs)
8. [Finalization](#finalization)

---

## Network

Use `iwctl` for a **wireless** connection. Skip this section if using **ethernet**.

```bash
iwctl station list                       # 1. Find your wireless station name
iwctl station wlan0 scan                 # 2. Scan for nearby networks
iwctl station wlan0 get-networks         # 3. List discovered networks
iwctl station wlan0 connect <ssid>       # 4. Connect (replace <ssid> with your network name)
ping -c 3 artixlinux.org                 # 5. Verify connectivity
```

---

## Drive Setup

> The examples below use `/dev/nvme0n1`. Replace it with your actual device name.

### Partitioning

Use `cfdisk` to interactively partition the drive with the following layout:

| Partition        | Type             | Size      | Purpose             |
| ---------------- | ---------------- | --------- | ------------------- |
| `/dev/nvme0n1p1` | EFI System       | 512 MiB   | EFI                 |
| `/dev/nvme0n1p2` | Linux filesystem | 256 MiB   | Boot                |
| `/dev/nvme0n1p3` | Linux filesystem | Remaining | Unified root & home |

### Formatting

```bash
mkfs.fat -F32 /dev/nvme0n1p1
fatlabel /dev/nvme0n1p1 ESP

mkfs.ext4 -L BOOT /dev/nvme0n1p2

mkfs.btrfs -L MAIN /dev/nvme0n1p3
```

> You may label partitions however you like.

### Creating Btrfs Subvolumes

Mount the Btrfs partition temporarily to create subvolumes:

```bash
mount /dev/nvme0n1p3 /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@opt

# Optional — only needed if you use Docker or libvirt
btrfs subvolume create /mnt/@docker
btrfs subvolume create /mnt/@libvirt

umount /mnt
```

### Mounting Subvolumes

The following mount options are used for all subvolumes **except** `@swap`:

| Option            | Effect                                       |
| ----------------- | -------------------------------------------- |
| `noatime`         | Disables access time tracking (performance)  |
| `compress=zstd:3` | Transparent Zstd compression at level 3      |
| `ssd`             | Enables SSD-optimized I/O heuristics         |
| `discard=async`   | Asynchronous TRIM support for SSDs           |
| `space_cache=v2`  | Uses the v2 free space cache (more reliable) |
| `subvol=<name>`   | Selects which subvolume to mount             |

> ⚠️ The `@swap` subvolume is mounted **without** `compress=zstd:3`. Btrfs swapfiles require the no-copy-on-write (`+C`) attribute, which is incompatible with compression. Using compression on the swap subvolume will prevent the swapfile from being activated.

```bash
# Root and general subvolumes
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@          /dev/nvme0n1p3 /mnt
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home      /dev/nvme0n1p3 /mnt/home
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_log   /dev/nvme0n1p3 /mnt/var/log
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_cache /dev/nvme0n1p3 /mnt/var/cache
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_tmp   /dev/nvme0n1p3 /mnt/var/tmp
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@tmp       /dev/nvme0n1p3 /mnt/tmp
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@snapshots /dev/nvme0n1p3 /mnt/.snapshots
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@opt       /dev/nvme0n1p3 /mnt/opt

# Swap — NO compression flag
mount --mkdir -o noatime,ssd,discard=async,space_cache=v2,subvol=@swap                      /dev/nvme0n1p3 /mnt/swap

# Optional
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@docker    /dev/nvme0n1p3 /mnt/var/lib/docker
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@libvirt   /dev/nvme0n1p3 /mnt/var/lib/libvirt

# Boot partitions
mount --mkdir /dev/nvme0n1p2 /mnt/boot
mount --mkdir /dev/nvme0n1p1 /mnt/boot/efi
```

---

## Base Install

Install the base system and essential packages using `basestrap`:

```bash
basestrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware \
    efibootmgr grub dinit elogind-dinit \
    iwd iwd-dinit networkmanager networkmanager-dinit \
    zramen zramen-dinit btrfs-progs openresolv vim
```

> `openresolv` is required for `/etc/resolvconf.conf` to work correctly.

Generate the filesystem table, then chroot into the new system:

```bash
fstabgen -U /mnt >> /mnt/etc/fstab
artix-chroot /mnt
```

---

## Swap & Zram

### Btrfs Swapfile

Setting `+C` (no-copy-on-write) on the directory **before** creating the swapfile ensures the file inherits the attribute correctly. Setting it after the fact on an already-written file has no retroactive effect on existing data.

```bash
chattr +C /swap
btrfs filesystem mkswapfile --size 8G --uuid clear /swap/swapfile
```

> You may set the size however you like.

Then add the swapfile entry to `/etc/fstab`:

```
# /etc/fstab
/swap/swapfile    none    swap    defaults    0 0
```

### Zram with zramen

Create `/etc/dinit.d/config/zramen.conf` with the following content:

```json
# /etc/dinit.d/config/zramen.conf
ZRAM_SIZE=50              # Percentage of total RAM to allocate (e.g. 50 = 50%)
ZRAM_COMP_ALGORITHM=zstd
ZRAM_PRIORITY=100
```

> Zram will be compressed using `zstd` and given priority over the swapfile. Increase `ZRAM_SIZE` to `65` if you want to allocate more RAM.

---

## Users & Locale

### Timezone & Hardware Clock

```bash
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
```

### Locale

Uncomment your locale in `/etc/locale.gen`. For US English:

```
# /etc/locale.gen
en_US.UTF-8 UTF-8
```

Generate the locale:

```bash
locale-gen
```

Set the active locale:

```
# /etc/locale.conf
LANG=en_US.UTF-8
```

### Hostname

```
# /etc/hostname
artix
```

Configure the local hosts file, making sure the entry in `127.0.1.1` matches what you set in `/etc/hostname`:

```
# /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    artix.localdomain    artix
```

### Root & User Accounts

Set the root password, then create your user:

```bash
passwd

useradd -mG wheel -s /bin/bash <name>
passwd <name>
```

Grant the `wheel` group sudo access by editing the sudoers file:

```bash
EDITOR=vim visudo
```

Uncomment the following line:

```
%wheel ALL=(ALL:ALL) ALL
```

---

## Network Configuration

### iwd Backend for NetworkManager

```ini
# /etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd

# /etc/NetworkManager/conf.d/openresolv.conf
[main]
dns=default
rc-manager=resolvconf
```

### DNS

```
# /etc/resolvconf.conf
name_servers="94.140.14.14 94.140.15.15"
name_servers_append="1.1.1.1 1.0.0.1"
```

> These use AdGuard DNS as primary and Cloudflare as fallback. Adjust to your preference.

---

## GRUB & initramfs

Install and configure GRUB:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Add the `btrfs` module to `mkinitcpio` and regenerate the initramfs:

```
# /etc/mkinitcpio.conf
MODULES=(btrfs)
```

```bash
mkinitcpio -P
```

---

## Finalization

Exit the chroot and reboot:

```bash
exit
reboot
```

Once logged into your user account, enable the necessary services:

```bash
sudo dinitctl enable NetworkManager
sudo dinitctl enable iwd
```

For zramen to work correctly:

```json
# /etc/dinit.d/zramen
...
env-file    =   /etc/dinit.d/config/zramen.conf
```

> Also comment the logfile line because zramen starts too early

Then enable zramen:

```bash
sudo dinitctl enable zramen
```
