#!/bin/bash

pacstrap -K /mnt base linux-zen linux-firmware linux-zen-headers base-devel efibootmgr grub networkmanager btrfs-progs vim cryptsetup zram-generator

genfstab -U /mnt >> /mnt/etc/fstab

# arch-chroot /mnt
