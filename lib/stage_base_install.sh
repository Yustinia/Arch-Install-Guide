#!/bin/bash

pacstap -K /mnt "${PACSTRAP_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# arch-chroot /mnt
