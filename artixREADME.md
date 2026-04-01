# Artix Install Guide

> A personal guide for manually installing Artix Linux — focused on dinit — with:
> `btrfs subvolumes`, `swap`, and `zram`
> soon with `LUKS` and `LVMs`

## Network

Use `iwctl` for **wireless** connection; otherwise, skip if using **ethernet** connection.

```bash
iwctl station list                        # 1. Find your wireless station name
iwctl station wlan0 scan                  # 2. Scan for nearby networks
iwctl station wlan0 get-networks          # 3. List discovered networks
iwctl station wlan0 connect <ssid>        # 4. Connect (replace <ssid> with your network name)
ping -c 3 artixlinux.org                  # 5. Verify connectivity
```

## Drive Setup

> The device is `/dev/nvme0n1`, replace `nvme0n1` with your device

Using `cfdisk` to interactively partition the drive with the following layout:

| Block            | Type             | Size      | Purpose             |
| ---------------- | ---------------- | --------- | ------------------- |
| `/dev/nvme0n1p1` | EFI System       | 512MiB    | EFI                 |
| `/dev/nvme0n1p2` | Linux filesystem | 256MiB    | BOOT                |
| `/dev/nvme0n1p3` | Linux filesystem | Remaining | Unified ROOT & HOME |

Format & label (for clarity) the partitions:

```bash
mkfs.fat -F32 /dev/nvme0n1p1
fatlabel /dev/nvme0nap1 ESP

mkfs.ext4 -L BOOT /dev/nvme0n1p2

mkfs.btrfs -L MAIN /dev/nvme0n1p3
```

> You may label the partition however you like

Mount `/dev/nvme0n1p3` to `/mnt` for subvolume creation:

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

btrfs subvolume create /mnt/@docker
btrfs subvolume create /mnt/@libvirt
```

> Docker and libvirt are optional unless you use those tools

Then unmount `/mnt`:

```bash
 umount /mnt
```

Now mount the partitions & subvolumes — with the options — to ther respective mountpoints:

| Option            | Effect                                       |
| ----------------- | -------------------------------------------- |
| `noatime`         | Disables access time tracking (performance)  |
| `compress=zstd:3` | Transparent Zstd compression at level 3      |
| `ssd`             | Enables SSD-optimized I/O heuristics         |
| `discard=async`   | Asynchronous TRIM support for SSDs           |
| `space_cache=v2`  | Uses the v2 free space cache (more reliable) |
| `subvol=<name>`   | Selects which subvolume to mount             |

```bash
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@          /dev/nvme0n1p3  /mnt
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home      /dev/nvme0n1p3  /mnt/home
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_log   /dev/nvme0n1p3  /mnt/var/log
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_cache /dev/nvme0n1p3  /mnt/var/cache
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@var_tmp   /dev/nvme0n1p3  /mnt/var/tmp
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@tmp       /dev/nvme0n1p3  /mnt/tmp
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@snapshots /dev/nvme0n1p3  /mnt/.snapshots
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@swap      /dev/nvme0n1p3  /mnt/swap
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@opt       /dev/nvme0n1p3  /mnt/opt

mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@docker    /dev/nvme0n1p3  /mnt/var/lib/docker
mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@libvirt   /dev/nvme0n1p3  /mnt/var/lib/libvirt

mount --mkdir /dev/nvme0n1p2    /mnt/boot
mount --mkdir /dev/nvme0n1p1    /mnt/boot/efi
```

## Base Install

Install the base system and essential packages using `basestrap`:

```bash
basestrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware \
    efibootmgr grub dinit elogind-dinit iwd iwd-dinit networkmanager networkmanager-dinit \
    zramen zramen-dinit btrfs-progs vim
```

Generate the filesystem table before chrooting:

```bash
fstabgen -U /mnt >> /mnt/etc/fstab
artix-chroot /mnt
```

## Swap & Zram

To create a BTRFS swapfile, follow below:

```bash
chattr +C /swap
btrfs filesystem mkswapfile --size 8G --uuid clear /swap/swapfile
chattr +C /swap/swapfile
```

> You may set the size however you like

Then edit the fstab to add the entry below:

```bash
# /etc/fstab
/swap/swapfile      none        swap        default     0 0
```

For zram using zramen, create and edit the file on `/etc/zramen.conf`:

```bash
# /etc/zramen.conf
ZRAM_SIZE=50
ZRAM_COMP_ALGORITHM=zstd
ZRAM_PRIORITY=100
```

> ZRAM_SIZE is percent based, you can allocate 65% of ram by replacing 50 with 65

## User & Time

```bash
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
```

Edit `/etc/locale.gen` using your editor to find and uncomment your locale.
For US English:

```bash
# /etc/locale.gen
en_US.UTF-8 UTF-8
```

Then generate the locale:

```bash
locale-gen
```

Set the locale and console keymap:

```bash
# /etc/locale.conf
LANG=en_US.UTF-8

# /etc/vconsole.conf
KEYMAP=us
```

Set the machine hostname:

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

> Ensure that the entry you place inside `/etc/hostname` is the same for `127.0.1.1`

Create the **root** password then your user account:

```bash
passwd

useradd -mG wheel -s /bin/bash <name>
passwd <name>
```

Grant the wheel group **sudo** perms by editing the sudoers file:

```bash
EDITOR=vim visudo

%wheel ALL(ALL:ALL) ALL
```

> Uncomment the wheel group
