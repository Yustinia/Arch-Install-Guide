#!/bin/bash

arch-chroot /mnt systemctl enable NetworkManager

echo "Enabled NetworkManager"
