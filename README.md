# Arch Linux Installation Guide

This is a guide that shows my _personal preference_ in manually installing Arch Linux with BTRFS subvolumes, luks encryption, lvm, swap, and zram features.

## NETWORK

Use `iwctl` to connect wirelessly. Otherwise, if already using ethernet, skip the process.

1. Obtain the station: `iwctl station list`
2. Scan for networks: `iwctl station wlan0 scan`
3. List all networks: `iwctl station wlan0 get-networks`
4. Connect to a network: `iwctl station wlan0 connect <ssid>` and provide the passphrase
5. Verify connection: `ping archlinux.org`

## SETTING UP THE DRIVE

Use `lsblk -f` to show you available drives. Using `/dev/nvme0n1` as an example.

Use `cfdisk /dev/nvme0n1` to interactively partition the drive.

| Block          | Type             | Size   |
| -------------- | ---------------- | ------ |
| /dev/nvme0n1p1 | EFI              | 1GiB   |
| /dev/nvme0n1p2 | Linux filesystem | 512MiB |
| /dev/nvme0n1p3 | Linux filesystem | Any    |

Then encrypt the 3rd partition with `cryptsetup luksFormat /dev/nvme0n1p3`, give it a passphrase and confirm it.

Open the encryption with `cryptsetup open /dev/nvme0n1p3 encrypt`, replace encrypt with your choice.

Format the partitions:

1. `mkfs.fat -F32 /dev/nvme0n1p1`
2. `fatlabel /dev/nvme0n1p1 EFI`
3. `mkfs.ext4 -L boot /dev/nvme0n1p2`
4. `pvcreate /dev/mapper/encrypt`
5. `vgcreate vg0 /dev/mapper/encrypt`
6. `lvcreate -L 50G -n arch-root vg0`
7. `lvcreate -l 100%FREE -n arch-home vg0`
8. `mkfs.btrfs -L root /dev/vg0/arch-root`
9. `mkfs.ext4 -L home /dev/vg0/arch-home`

Mount arch-root to create the subvolumes using `mount /dev/vg0/arch-root /mnt`

Create the subvolumes:

1. `btrfs subvolume create /mnt/root`
2. `btrfs subvolume create /mnt/tmp`
3. `btrfs subvolume create /mnt/var_log`
4. `btrfs subvolume create /mnt/var_cache`
5. `btrfs subvolume create /mnt/var_tmp`
6. `btrfs subvolume create /mnt/docker`
7. `btrfs subvolume create /mnt/libvirt`
8. `btrfs subvolume create /mnt/swap`
9. `btrfs subvolume create /mnt/opt`
10. `btrfs subvolume create /mnt/snapshots`

`umount /mnt` to unmount it. Take note of the command `umount`, it is spelled like that.

Mount the following subvolumes to their respective mountpoints:

1. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=root /dev/vg0/arch-root /mnt`
2. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=tmp /dev/vg0/arch-root /mnt/tmp`
3. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=var_log /dev/vg0/arch-root /mnt/var/log`
4. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=var_cache /dev/vg0/arch-root /mnt/var/cache`
5. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=var_tmp /dev/vg0/arch-root /mnt/var/tmp`
6. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=docker /dev/vg0/arch-root /mnt/var/lib/docker`
7. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=libvirt /dev/vg0/arch-root /mnt/var/lib/libvirt`
8. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=swap /dev/vg0/arch-root /mnt/swap`
9. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=opt /dev/vg0/arch-root /mnt/opt`
10. `mount --mkdir -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=snapshots /dev/vg0/arch-root /mnt/.snapshots`

> It's better to use the same options on each, this ensures uniform fstab entries on generation.

Mount the rest of the partitions:

1. `mount --mkdir /dev/nvme0n1p2 /mnt/boot`
2. `mount --mkdir /dev/nvme0n1p1 /mnt/boot/efi`
3. `mount --mkdir /dev/vg0/arch-home /mnt/home`

## BASE INSTALL

Using the `pacstrap` command to install the following packages:

1. `pacstrap -K /mnt base linux-zen linux-zen-headers base-devel git efibootmgr grub iwd btrfs-progs vim cryptsetup lvm2 zram-generator`
2. `genfstab -U /mnt >> /mnt/etc/fstab`
3. `arch-chroot /mnt`

## SWAP AND ZRAM

Use the following commands for a BTRFS swapfile.

1. `btrfs filesystem mkswapfile --size 8G --uuid clear /swap/swapfile`
2. `chattr +C /swap`
3. `chattr +C /swap/swapfile`

Add the entry inside `/etc/fstab`.

`/swap/swapfile none swap default 0 0`

For ZRAM, ensure that you installed `zram-generator`.

1. `mkdir -pv /etc/systemd/zram-generator.conf.d/`
2. `touch /etc/systemd/zram-generator.conf.d/zram.conf`

Inside the `zram.conf` file, add the entries:

```bash
[zram0]
zram-size = ram / 2     # you can also set it as 65% by "ram * 0.65"
compression-algorithm = zstd
swap-priority = 100
```

Then save the file.

## TIME ZONE

We assign the time zone of your country and set it as localtime.

```bash
ln -sf /usr/share/zoneinfo/<continent>/<city> /etc/localtime
hwclock --systohc
```

Next up we get our locale. In this guide I'm going to use `en_US.UTF-8`.

Inside `/etc/locale.gen`, find your locale.

`en_US.UTF-8` Remove the comment (#) before it and save.

Run `locale-gen` to generate the chosen locale.

Inside `/etc/locale.conf`, add `LANG=en_US.UTF-8` or the locale that you chose and save.

Inside `/etc/vconsole.conf`, add `KEYMAP=us` then save.

Inside `/etc/hostname`, give your device your desired hostname (it can be anything). I will use _Arch_ for this.

Then in `/etc/hosts` add the following.

```bash
127.0.0.1   localhost
::11        localhost
127.0.1.1   Arch.localdomain  Arch
```

## USER SETUP

Creating your user account:

1. `useradd -mG wheel -s /bin/bash <name>`
2. `passwd <name>`
3. `EDITOR=vim visudo` and uncomment `%wheel ALL=(ALL:ALL) ALL`

## SERVICES

Enable networking using `systemctl enable iwd.service`.

## GRUB AND INITRAMFS

Before we install the GRUB bootloader, we need to setup the encrypted partition.

`blkid -o value -s UUID /dev/nvme0n1p3 >> /etc/default/grub` # LUKS container
`blkid -o value -s UUID /dev/vg0/arch-root >> /etc/default/grub` # root uuid

Then inside `/etc/default/grub`.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="rd.luks.name={LUKS UUID}=encrypt root=/dev/vg0/arch-root"     # only append the new entry from the existing line
```

Uncomment `GRUB_ENABLE_CRYPTODISK=y`.

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloaderid=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Now in `/etc/mkinitcpio.conf`.

```bash
MODULES=(btrfs)

# add "sd-encrypt & lvm2" betweem block and filesystems
HOOKS=(block sd-encrypt lvm2 filesystems)
```

And enter `mkinitcpio -P`.

Finally, `exit` the chroot environment and `systemctl reboot now`.
