#!/bin/bash

pacstrap -K /mnt "${PACSTRAP_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# arch-chroot /mnt
