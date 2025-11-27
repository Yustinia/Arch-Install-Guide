#!/bin/bash

arch-chroot /mnt passwd

arch-chroot /mnt useradd -m -G wheel -s /bin/bash "${USERNAME}"

arch-chroot /mnt passwd "${USERNAME}"

sed -i '/^#\s*%wheel\s\+ALL=(ALL:ALL)\s\+ALL/s/^#\s*//' /mnt/etc/sudoers
