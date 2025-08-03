# Arch Install Guide

Arch Install Guide with BTRFS and EXT4 settings with necessary fixes

## PREPARE NETWORK

```
iwctl
station wlan0 connect (ssid)
ping archlinx.org -c10
```

## PARTITION and MOUNT for EXT4

```
cfdisk /dev/sda

# /dev/sda1 = EFI/ESP
# /dev/sda2 = ROOT
# /dev/sda3 = HOME

mkfs.fat -F 32 /dev/sda1
fatlabel /dev/sda1 ESP

mkfs.ext4 -L ROOT /dev/sda2
mkfs.ext4 -L HOME /dev/sda3

mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot
mount --mkdir /dev/sda3 /mnt/home

```

## PARTITION and MOUNT for BTRFS

```
cfdisk /dev/sda

# /dev/sda1 = EFI/ESP
# /dev/sda2 = BTRFS

mkfs.fat -F 32 /dev/sda1
fatlabel /dev/sda1 ESP

mkfs.btrfs -L MAIN /dev/sda2
mount /dev/sda2 /mnt
```

Creating Subvolumes
```
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@swap
```

zstd:1-15 to define compression (1=default 15=max)
```
mount -o noatime,compress=zstd:5,ssd,discard=async,space_cache=v2,subvol=@ /dev/sda2 /mnt
mkdir -pv /mnt/home
mount -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home /dev/sda2 /mnt/home
mkdir -pv /mnt/swap
mount -o noatime,subvolume=@swap /dev/sda2 /mnt/swap
mkdir -pv /mnt/boot
mount /dev/sda1 /mnt/boot
```

## SWAPFILE

```
mkswap -U clear --size 4G --file /swap/swapfile
btrfs filesystem mkswapfile --size 4G --uuid clear /swap/swapfile
swapon /swap/swapfile
```

/etc/fstab
```
/swap/swapfile none swap default 0 0
```

## INSTALLING BASE SYSTEM

```
pacstrap -K /mnt base linux-firmware linux base-devel efibootmgr grub networkmanager btrfs-progs vim
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

## TIME ZONE

```
ln -sf /usr/share/zoneinfo/(continent)/(city) /etc/localtime
hwclock --systohc
```

/etc/locale.gen
Find your locale (en_US.UTF-8) then uncomment

`locale-gen`

/etc/locale.conf
`LANG=en_US.UTF-8`

/etc/hostname
Give your hostname

/etc/hosts
```
127.0.0.1 localhost
::1       localhost
127.0.1.1 (hostname).localdomain (hostname)
```

## USER SETUP

Set Root Password
`passwd`

Users
```
useradd -m -G wheel -s /bin/bash (username)
passwd (username)
```

Uncomment wheel group
`EDITOR=vim visudo`

## SYSTEMCTL

```
systemctl enable networkmanager
```

## GRUB

```
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## FINAL PREPARATION

If BTRFS
/etc/mkinitcpio.conf
```
MODULES=(btrfs)
mkinitcpio -P
```

/etc/default/grub
```
GRUB_TIMEOUT=(preference)
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_DISABLE_SUBMENU=y

grub-mkconfig -o /boot/grub/grub.cfg
```

## ERROR PGP FIXES

```
pacman-key --init
pacman-key --populate
```

### EXTRAS

Kernels: linux linux-lts linux-zen linux-cachyos # Cachy repos must be added before installing cachy related pkgs
Headers: linux-headers linux-lts-headers linux-zen-headers linux-cachyos-headers
Hardware: amd-ucode intel-ucode
Audio: pipewire pipewire-pulse pipewire-alsa wireplumber
Optional: fastfetch btop reflector vim neovim nano

`sudo reflector -p https -f 8 --sort rate -c "countries" --save /etc/pacman.d/mirrorlist`

### FIX RTL8852BE WIFI (POST INSTALL)

```
yay -S --needed rtw89-dkms-git power-profiles-daemon

sudo systemctl enable --now power-profiles-daemon.service
powerprofilesctl set performance
```

/etc/modprobe.d/rtw89.conf
```
options rtw89_core_git debug_mask=0x0
options rtw89_core_git disable_ps_mode=y

options rtw89_pci_git disable_clkreq=y
options rtw89_pci_git disable_aspm_l1=y
options rtw89_pci_git disable_aspm_l1ss=y

options rtw89_usb_git switch_usb_mode=y
```

Blacklist the in-kernel rtw89 drivers
```
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
