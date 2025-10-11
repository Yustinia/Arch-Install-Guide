# Arch Linux Installation Guide

This is a minimal guide that helps you in the manual installation of Arch Linux so you can finally proclaim the title and enable yourself the privilege of *"I Use Arch BTW"*.

## PREPARING NETWORK

Let's start with wireless connectivity. If you use ethernet, you may skip this part.

We'll use `iwctl` to connect to wifi.

```bash
iwctl
station wlan0 connect {ssid}
exit
ping archlinux.org -c10 # test connection
```

## PARTITION and MOUNT (EXT4)

This part focuses on EXT4 partitioning and mounting. If you prefer BTRFS, skip this part.

Use `cfdisk {/dev/sdX}` to interactively create your partitions. Please do keep in mind that it may be different across devices.

| Block | Type | Size |
| --- | --- | --- |
| /dev/sda1 | EFI | 1G |
| /dev/sda2 | Linux filesystem | Any |
| /dev/sda3 | Linux filesystem | Any |

Afterwards, we format the partitions:

```bash
mkfs.fat -F32 /dev/sda1 # BOOT Partition
fatlabel /dev/sda1 ESP # Labelling for clarity

mkfs.ext4 -L ROOT /dev/sda2 # ROOT Partition
mkfs.ext4 -L HOME /dev/sda3 # HOME Partition

mount /dev/sda2 /mnt # Mount ROOT
mount --mkdir /dev/sda1 /mnt/boot # Mount BOOT
mount --mkdir /dev/sda3 /mnt/home # Mount HOME
```

## PARTITION, MOUNT, & SUBVOLUMES (BTRFS)

This part focuses on BTRFS partitioning. If you prefer EXT4, do above.

Use `cfdisk {/dev/sdX}` to interactively create your partitions.

| Block | Type | Size |
| --- | --- | --- |
| /dev/sda1 | EFI | 1G |
| /dev/sda2 | Linux filesystem | Any |

Afterwards, we format the partitions.

```bash
mkfs.fat -F32 /dev/sda1 # BOOT Parition
fatlabel /dev/sda1 ESP # Labelling for clarity

mkfs.btrfs -L MAIN /dev/sda2 # ROOT Partition
mount /dev/sda2 /mnt # Temporary mount
```

Then we will create our subvolumes.

```bash
btrfs subvolume create /mnt/@ # ROOT
btrfs subvolume create /mnt/@home # HOME
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@tmp
umount /mnt
```

After creating, we mount the subvolumes. Additionally, you can define zstd compression with `compress=zstd:1` through `compress=zstd:15`. Keep in mind that every other subvolume **will** adopt that zstd compression.

```bash
mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@ /dev/sda2 /mnt

mount --mkdir -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@home /dev/sda2 /mnt/home
mount --mkdir -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@var_log /dev/sda2 /mnt/var/log
mount --mkdir -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@var_cache /dev/sda2 /mnt/var/cache
mount --mkdir -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@var_tmp /dev/sda2 /mnt/var/tmp
mount --mkdir -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@tmp /dev/sda2 /mnt/tmp

mkdir -pv /mnt/boot
mount /dev/sda1 /mnt/boot # BOOT Mount
```

> My personal suggestion is use BTRFS for ROOT and EXT4 for HOME. This was you can utilize snapshots and compression in the ROOT partition while benefitting speed using EXT4.

## INSTALLING THE BASE System

We're going to use pacstrap to install the necessary packages for Arch.

```bash
pacstrap -K /mnt base linux linux-firmware linux base-devel efibootmgr grub networkmanager btrfs-progs vim

genfstab -U /mnt >> /mnt/etc/fstab # Generate fstab

arch-chroot /mnt # Chroot into Arch
```

## SWAP FILE

This is important for hibernation/suspend/sleep to work properly.

For EXT4:

```bash
mkdir -pv /SWAP
mkswap -U clear --size 4G --file /swap/swapfile

swapon /swap/swapfile # Activate swapfile if not yet activated
```

For BTRFS:

```bash
btrfs subvolume create /swap
btrfs filesystem mkswapfile --size 4G --uuid clear /swap/swapfile
lsattr /swap/swapfile # Check for "C"

swapon /swap/swapfile # Activate swapfile if not yet activated
```

Inside `/etc/fstab` add `/swap/swapfile none swap default 0 0` at the bottom and save the file.

## ZRAM GENERATOR

We install zram-generator first with `sudo pacman -S --needed zram-generator`.

Then create a directory using `mkdir -pv /etc/systemd/zram-generator.conf.d/`.

`cd` into the directory and do `touch zram.conf`.

Add the following inside the conf file.

```bash
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
```

Save the file and let's activate it.

```bash
sudo systemctl daemon-reexec && systemctl restart systemd-zram-setup@zram0.service
```

Verify if zram and swap exists with `lsblk` and `swapon --show`.

## TIME ZONE

We assign the time zone of your country and set it as localtime.

```bash
ln -sf /usr/share/zoneinfo/{continent}/{city} /etc/localtime
hwclock --systohc
```

Next up we get our locale. In this guide I'm going to use `en_US.UTF-8`.

Inside `/etc/locale.gen`, find your locale.

`en_US.UTF-8` Remove the comment (#) before it and save.

Run `locale-gen` to generate the chosen locale.

Inside `/etc/locale.conf`, add `LANG=en_US.UTF-8` or the locale that you chose and save

Inside `/etc/hostname`, give your device your desired hostname (it can be anything). I will use *HPArch* for this.

Then in `/etc/hosts` add the following.

```bash
127.0.0.1   localhost
::11        localhost
127.0.1.1   HPArch.localdomain  HPArch
```

## USER SETUP

Give you root user a password with `passwd`.

Then create your user account with `useradd -m -G wheel -s /bin/bash {name}`.

Give the user account a password with `passwd {name}`.

With `EDITOR={editor} visudo`, in this case I use vim. `EDITOR=vim visudo`.

Uncomment the line (#) `%wheel ALL=(ALL:ALL) ALL` and save it.

## SYSTEMCTL

Let's enable the network manager for wireless connectivity with `systemctl enable NetworkManager`.

## INSTALLING THE GRUB BOOTLOADER

Now we install the bootloader for our system.

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloaderid=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## FINAL PREPARATION

If you use BTRFS, you must do this additional step

In `/etc/mkinitcpio.conf`, add `btrfs` inside the parentehses of `MODULES`. Save it and run `mkinitcpio -P`.

Then finally we reboot the system and welcome to Arch!

> You don't need to do this below, it's a preference.

Inside `/etc/default/grub`.

```bash
GRUB_TIMEOUT={seconds} # How long you want 'til GRUB automatically selects
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true # Remove the comment
GRUB_DISABLE_SUBMENU=y # Remove the comment
```

Save and regenerate the GRUB config with `grub-mkconfig -o /boot/grub/grub.cfg`

### ERROR PGP FIXES

When you try to boot into your new Arch install and attempt to update with `sudo pacman -Syu`. Do the following below to fix PGP Errors.

```bash
pacman-key --init
pacman-key --populate
```

Then try to update again with `sudo pacman -Syu`.

### EXTRAS

**ONLY DOWNLOAD WHAT YOU REQUIRE**

Kernels:

```bash
sudo pacman -S --needed linux linux-lts linux-zen linux-cachyos
```

> CachyOS repos must be added first for full functionality for Cachy related pkgs/deps.

Kernel Headers:

```bash
sudo pacman -S --needed linux-headers linux-lts-headers linux-zen-headers linux-cachyos-headers
```

UCode:

```bash
sudo pacman -S --needed amd-ucode intel-ucode
```

Audio:

```bash
sudo pacman -S --needed pipewire pipewire-pulse pipewire-alsa wireplumber
```

Optional:

```bash
sudo pacman -S --needed fastfetch btop reflector vim nvim nano
```

Faster Mirrors:
```bash
sudo reflector -p https -f 8 --sort rate -c "countries" --save /etc/pacman.d/mirrorlist
```

### FIX RTW89 WIFI

This is my personal fix for Realtek Wifi Cards with the RTW89.

```bash
yay -S --needed rtw89-dkms-git power-profiles-daemon
systemctl enable --now power-profiles-daemon.service
powerprofilesctl list # List available profiles
powerprofilesctl set performance # Set maximum profile
```

Inside `/etc/NetworkManager/conf.d/00-wifi-powersave.conf`.

```bash
[connection]
wifi.powersave = 2
```

Inside `/etc/default/grub`.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=off" # Add this parameter
```

Inside `/etc/modprobe.d/rtw89.conf`, set all options to "y".

```bash
options rtw89_core_git debug_mask=0x0
options rtw89_core_git disable_ps_mode=y

options rtw89_pci_git disable_clkreq=y
options rtw89_pci_git disable_aspm_l1=y
options rtw89_pci_git disable_aspm_l1ss=y

options rtw89_usb_git switch_usb_mode=y
```

Regenerate cpio and grub configs.

```bash
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
```
