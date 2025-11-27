#!/bin/bash

CRYPT_PARAMS="rd.luks.name=$(blkid -o value -s UUID ${BTRFS_UUID})=${LUKS_NAME} root=${LUKS_PART}"

arch-chroot /mnt sed -i \
    "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ ${CRYPT_PARAMS}\"/" \
    /etc/default/grub

arch-chroot /mnt sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
