#!/bin/bash

arch-chroot /mnt sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf

arch-chroot /mnt sed -i 's/\(block\)/\1 sd-encrypt/' /etc/mkinitcpio.conf

arch-chroot /mnt mkinitcpio -P
