#!/bin/bash

export CRYPT_PARAMS="rd.luks.name=${BTRFS_UUID}=${LUKS_NAME} root=${LUKS_PART}"

sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\"$/ ${CRYPT_PARAMS}\"/" /mnt/etc/default/grub

sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /mnt/etc/default/grub

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
