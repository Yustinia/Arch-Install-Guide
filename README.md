# Arch Linux Installation Guide

This is a guide to manually install Arch Linux in both BTRFS and EXT4, alongside implement features like SWAP and ZRAM in a clean install. For you to make the flawless switch.

## PREPARE NETWORK

Use the command **`iwctl`** for networks.

```
iwctl
station wlan0 connect {ssid}
ping archlinux.org -c10
```

## PARTITION and MOUNT (EXT4)

Use **`cfdisk {/dev/sdX}`** to interactively create your partitions.

```
# /dev/sda1 = ESP/EFI | 1GB Type: EFI System
# /dev/sda2 = ROOT | Type: Linux Filesystem
# /dev/sda3 = HOME | Type: Linux Filesystem
```
Commands:

```
mkfs.fat -F32 /dev/sda1 | BOOT partition
fatlabel /dev/sda1 ESP | Labelling for clarity

mkfs.ext4 -L ROOT /dev/sda2 | ROOT partition
mkfs.ext4 -L HOME /dev/sda3 | HOME partition

mount /dev/sda2 /mnt | mount ROOT
mount --mkdir /dev/sda1 /mnt/boot | mount BOOT
mount --mkdir /dev/sda3 /mnt/home | mount HOME
```

## PARTITION and MOUNT (BTRFS)

Use **`cfdisk {/dev/sdX}`** to interactively create your partitions.

```
# /dev/sda1 = ESP/EFI | 1GB Type: EFI System
# /dev/sda2 = BTRFS | Main partition
```

Commands:

```
mkfs.fat -F32 /dev/sda1 | BOOT parition
fatlabel /dev/sda1 ESP | Labelling for clarity

mkfs.btrfs -L MAIN /dev/sda2
mount /dev/sda2 /mnt | TEMPORARY MOUNT
```

### Creating Subvolumes (BTRFS)

Here we will create our ROOT and HOME subvolumes.

```
btrfs subvolume create /mnt/@ | ROOT
btrfs subvolume create /mnt/@home | HOME
umount /mnt
```

Afterwards, we mount the subvolumes and partitions.

```
mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@ /dev/sda2 /mnt | ROOT mount

mkdir-pv /mnt/home
mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@home /dev/sda2 /mnt/home | HOME mount

mkdir -pv /mnt/boot
mount /dev/sda1 /mnt/boot | BOOT mount
```

## INSTALLING THE BASE System

We're going to use pacstrap to install the necessary packages for Arch.

```
pacstrap -K /mnt base linux linux-firmware linux base-devel efibootmgr grub networkmanager btrfs-progs vim

genfstab -U /mnt >> /mnt/etc/fstab | Generates fstab

arch-chroot /mnt
```

## SWAP FILE

This is important for hibernation/sleep/suspend.

```
mkdir -pv /SWAP

# For EXT4
mkswap -U clear --size 4G --file /swap/swapfile

# For BTRFS
btrfs filesystem mkswapfile --size 4G --uuid clear /swap/swapfile

swapon /swap/swapfile | Activate swapfile
```

Inside **`/etc/fstab`** add **`/swap/swapfile none swap default 0 0`** at the bottom most part of the window and save the file.

## ZRAM GENERATOR

We install zram-generator first with **`sudo pacman -S --needed zram-generator`**.

Then create a directory using **`mkdir -pv /etc/systemd/zram-generator.conf.d/`**.

**`cd`** into the directory and execute **`touch zram.conf`**.

Edit the file and add the following.

```
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100

# Save the file

sudo systemctl daemon-reexec && systemctl restart systemd-zram-setup@zram0.service
```

Verify zram and swap existence with **`lsblk`** or **`swapon --show`**.

## TIME ZONE

We assign the time zone of your country and set it as localtime.

```
ln -sf /usr/share/zoneinfo/{continent}/{city} /etc/localtime
hwclock --systohc
```

Next up we get our locale. In this guide I'm going to use *en_US.UTF-8*.

Inside **`/etc/locale.gen`**, find your locale.

**`en_US.UTF-8`** Remove the comment (#) before it and save.

Run **`locale-gen`** to generate the chosen locale.

Inside **`/etc/locale.conf`**, add **`LANG=en_US.UTF-8`** or the locale that you chose and save

Inside **`/etc/hostname`**, give your device your desired hostname (it can be anything). I will use *HPArch* for this.

Then in **`/etc/hosts`** add the following.

```
127.0.0.1   localhost
::11        localhost
127.0.1.1   HPArch.localdomain  HPArch
```

## USER SETUP

Give you root user a password with **`passwd`**.

Then create your user account with **`useradd -m -G wheel -s /bin/bash {name}`**.

Give the user account a password with **`passwd {user}`**.

With **`EDITOR=vim visudo`** (or any text editor you downloaded), uncomment the wheel group.

**`%wheel ALL=(ALL:ALL) ALL`**.

## SYSTEMCTL

Let's enable the network manager for wireless connectivity.

**`systemctl enable NetworkManager`**

## GRUB BOOTLOADER

Now we install the bootloader for our system.

```
grub-install --target=x86_64-efi --efi-directory=/boot --bootloaderid=GRUB

grub-mkconfig -o /boot/grub/grub.cfg
```

## FINAL PREPARATION

If you used BTRFS, you must do this.

In **`/etc/mkinitcpio.conf`**.

Add **`btrfs`** inside the parentehses of **`MODULES`**. Save it and proceed with **`mkinitcpio -P`**.

Inside **`/etc/default/grub`**.

```
GRUB_TIMEOUT={seconds}
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true | Remove comment
GRUB_DISABLE_SUBMENU=y | Remove comment

# Save the regenerate config

grub-mkconfig -o /boot/grub/grub.cfg
```

### ERROR PGP FIXES

```
pacman-key --init
pacman-key --populate
```

### EXTRAS


Kernels: `linux linux-lts linux-zen linux-cachyos` | Cachy repos must be added first for Cachy related pkgs

Headers: `linux-headers linux-lts-headers linux-zen-headers linux-cachyos-headers`

Hardware: `amd/intel-ucode`

Audio: `pipewire pipewire-pulse pipewire-alsa wireplumber`

Optional: `fastfetch btop reflector vim nvim nano`

Update mirrorlist: `sudo reflector -p https -f 8 --sort rate -c "(countries)" --save /etc/pacman.d/mirrorlist`

### FIX RTW89 WIFI

```
yay -S --needed rtw89-dkms-git power-profiles-daemon

systemctl enable --now power-profiles-daemon.service
powerprofilesctl list   # List available profiles
powerprofilesctl set    # Set profile
```

Inside **`/etc/NetworkManager/conf.d/00-wifi-powersave.conf`** add

```
[connection]
wifi.powersave = 2
```

**`/etc/default/grub`**
```
GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=off" | Add this parameter
```

**`/etc/modprobe.d/rtw89.conf`**

```
options rtw89_core_git debug_mask=0x0
options rtw89_core_git disable_ps_mode=y

options rtw89_pci_git disable_clkreq=y
options rtw89_pci_git disable_aspm_l1=y
options rtw89_pci_git disable_aspm_l1ss=y

options rtw89_usb_git switch_usb_mode=y

# Blacklist the in-kernel rtw89 drivers
blacklist rtw89_8851bu
blacklist rtw89_8851be
blacklist rtw89_8851b
blacklist rtw89_8852au
blacklist rtw89_8852ae
blacklist rtw89_8852a
blacklist rtw89_8852b_common
blacklist rtw89_8852bu
blacklist rtw89_8852be
blacklist rtw89_8852b
blacklist rtw89_8852bte
blacklist rtw89_8852bt
blacklist rtw89_8852cu
blacklist rtw89_8852ce
blacklist rtw89_8852c
blacklist rtw89_8922au
blacklist rtw89_8922ae
blacklist rtw89_8922a
blacklist rtw89_core
blacklist rtw89_usb
blacklist rtw89_pci
```

```
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
```