# Arch Linux Installation Guide

This is a guide that shows my personal process in manually installing Arch Linux with BTRFS subvolumes, luks encryption, swap, and zram features.

A install script is also included does the following:

1. Configure the `user_conf.sh` to set defaults. You **must first configure** the variables inside the file.

2. Wipes the target disk and creates the necessary partitions.

3. Encrypts the root partition.

4. Formats and creates the necessary subvolumes.

5. Installs the base system.

6. Setup SWAP and ZRAM.

7. Configures localization.

8. Creates user and prompts for password.

9. Configure and regenerate GRUB and Initramfs.

## CHAPTERS

- [PREPARING NETWORK](#preparing-network)
- [PARTITION DRIVE](#partition-drive)
- [SECURE OUR DRIVE WITH CRYPTSETUP](#secure-our-drive-with-cryptsetup)
- [FORMAT MOUNT SUBVOLUMES](#format-mount-subvolumes)
- [INSTALLING THE BASE SYSTEM](#installing-the-base-system)
- [SWAP FILE](#swap-file)
- [ZRAM GENERATOR](#zram-generator)
- [TIME ZONE](#time-zone)
- [USER SETUP](#user-setup)
- [SYSTEMCTL](#systemctl)
- [GRUB BOOTLOADER](#grub-bootloader)
- [MKINITCPIO](#mkinitcpio)
- [ADDITIONAL SETUP](#additional-setup)

## PREPARING NETWORK

Let's start with wireless connectivity. If you use ethernet, you may skip this part.

We'll use `iwctl` to connect to wifi.

```bash
iwctl
station wlan0 connect {ssid}
exit
ping archlinux.org -c10 # test connection
```

## PARTITION DRIVE

Use `cfdisk {/dev/sdX}` to interactively create your partitions.

| Block     | Type             | Size |
| --------- | ---------------- | ---- |
| /dev/sda1 | EFI              | 1G   |
| /dev/sda2 | Linux filesystem | Any  |

## SECURE OUR DRIVE WITH CRYPTSETUP

We encrypt the partition where the ROOT would be i.e. `/dev/sda2`.

`cryptsetup luksFormat /dev/sda2`

Give it a password and confirm it.

`cryptsetup open /dev/sda2 {name}`

A common name convention is "cryptroot".

Using `lsblk` will list a new partition nested under `/dev/sda2`, we will use that.

## FORMAT MOUNT SUBVOLUMES

Afterwards, we format the partitions.

```bash
mkfs.fat -F32 /dev/sda1
fatlabel /dev/sda1 ESP

mkfs.btrfs -L MAIN /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```

Then we will create our subvolumes.

```bash
btrfs subvolume create /mnt/@       # ROOT
btrfs subvolume create /mnt/@home   # HOME
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@snapshots

umount /mnt
```

After creating, we mount the subvolumes. Additionally, you can define zstd compression with `compress=zstd:1` through `compress=zstd:15`. Keep in mind that every following subvolume mount **will** adopt the compression level regardless of explicit value.

```bash
mount -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ /dev/mapper/cryptroot /mnt
mount --mkdir /dev/sda1 /mnt/boot

# first mount option becomes the default for the entire BTRFS filesystem
mount --mkdir -o subvol=@home /dev/mapper/cryptroot /mnt/home
mount --mkdir -o subvol=@var_log /dev/mapper/cryptroot /mnt/var/log
mount --mkdir -o subvol=@var_cache /dev/mapper/cryptroot /mnt/var/cache
mount --mkdir -o subvol=@var_tmp /dev/mapper/cryptroot /mnt/var/tmp
mount --mkdir -o subvol=@tmp /dev/mapper/cryptroot /mnt/tmp
mount --mkdir -o subvol=@swap /dev/mapper/cryptroot /mnt/swap
mount --mkdir -o subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
```

## INSTALLING THE BASE SYSTEM

We're going to use pacstrap to install the necessary packages for Arch.

```bash
pacstrap -K /mnt base linux linux-firmware linux base-devel efibootmgr grub networkmanager btrfs-progs vim cryptsetup

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt
```

## SWAP FILE

This is important for hibernation/suspend/sleep to work properly.

```bash
btrfs filesystem mkswapfile --size {size}G --uuid clear /swap/swapfile
chattr +C /swap
chattr +C /swap/swapfile
lsattr /swap/swapfile       # check for "C", if it's present means it's fine
```

Inside `/etc/fstab` add.

```bash
/swap/swapfile none swap default 0 0
```

## ZRAM GENERATOR

We install zram-generator first with `sudo pacman -S --needed zram-generator`.

Then create a directory using `mkdir -pv /etc/systemd/zram-generator.conf.d/`.

`cd` into the directory and do `touch zram.conf`.

Add the following inside the conf file.

```bash
[zram0]
zram-size = ram / 2     # you can also set it as 65% by "ram * 0.65"
compression-algorithm = zstd
swap-priority = 100
```

Save the file.

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

Inside `/etc/locale.conf`, add `LANG=en_US.UTF-8` or the locale that you chose and save.

Inside `/etc/vconsole.conf`, add `KEYMAP=us` then save.

Inside `/etc/hostname`, give your device your desired hostname (it can be anything). I will use _HPArch_ for this.

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

## GRUB BOOTLOADER

Before we install the GRUB bootloader, we need to setup the encrypted partition.

`blkid -o value -s UUID /dev/mapper/cryptroot >> /etc/default/grub` # unencrypted UUID
`blkid -o value -s UUID /dev/sda2 >> /etc/default/grub` # encrypted UUID

Then inside `/etc/default/grub`.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="rd.luks.name={UUID of Encrypted}=cryptroot root=/dev/mapper/cryptroot"     # only append the new entry from the existing line
```

Uncomment `GRUB_ENABLE_CRYPTODISK=y`.

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloaderid=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## MKINITCPIO

In `/etc/mkinitcpio.conf`.

```bash
MODULES=(btrfs)

# add "sd-encrypt" betweem block and filesystems
HOOKS=(block sd-encrypt filesystems)
```

Then do `mkinitcpio -P`

> You don't need to do this below, it's a preference.

Inside `/etc/default/grub`.

```bash
GRUB_TIMEOUT={seconds}  # How long you want 'til GRUB automatically the highlighted option
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true   # Remove comment
GRUB_DISABLE_SUBMENU=y  # Remove comment
```

Save and generate the GRUB config with `grub-mkconfig -o /boot/grub/grub.cfg`.

```bash
exit    # assuming you're still chrooted
umount -R /mnt
systemctl reboot now
```

## ADDITIONAL SETUP

Let's include the `multilib` repo by modifying the `/etc/pacman.conf`.

Locate `multilib` and uncomment the header and [Include] line.

Save it then do `pacman -Syy` to refresh repos.

### ERROR PGP FIXES

When you try to boot into your new Arch install and attempt to update with `sudo pacman -Syu`. Do the following below to fix PGP Errors.

```bash
sudo pacman-key --init
sudo pacman-key --populate
sudo pacman -Syy     # refresh repos
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
sudo pacman -S --needed fastfetch btop reflector vim eza ripgrep fd git bat
```

Faster Mirrors:

```bash
sudo reflector -p https -f 8 --sort rate -c "{countries}" --save /etc/pacman.d/mirrorlist
```

AUR Helper

Choose either paru or yay.

```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

If you prefer bin files

```bash
git clone https://aur.archlinux.org/yay-bin.git
git clone https://aur.archlinux.org/paru-bin.git
```

### FIX RTW89 WIFI

This is my personal fix for Realtek Wifi Cards with the RTW89.

```bash
paru -S --needed rtw89-dkms-git power-profiles-daemon python-gobject
systemctl enable --now power-profiles-daemon.service
powerprofilesctl set performance # Set maximum profile
```

Inside `/etc/NetworkManager/conf.d/00-wifi-powersave.conf`.

```bash
[connection]
wifi.powersave = 2
```

Inside `/etc/default/grub`.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=off"      # Append this parameter at the end
```

Inside `/etc/modprobe.d/rtw89.conf`, set following options to "y".

```bash
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
