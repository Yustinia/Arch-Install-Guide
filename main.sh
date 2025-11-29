#!/bin/bash

set -e
set -u

if [[ $EUID -ne 0 ]]; then
    echo "Not the ROOT user"
    exit 1
fi

message=("This is an Arch Install script"
         "Configure the defaults via the user_conf.sh file"
         "If you like this script, please leave a star on the repo!"
         "Thank you!")

for line in "${message[@]}"; do
    echo "$line"
    sleep 0.5s
done


get_disk_uuid() {
    export EFI_PART="${DISK}1"
    export ROOT_PART="${DISK}2"

    echo "$EFI_PART"
    echo "$ROOT_PART"
}

get_encryption_uuid() {
    BTRFS_UUID="$(blkid -o value -s UUID "$ROOT_PART")"
    export BTRFS_UUID
    LUKS_UUID="$(blkid -o value -s UUID "$LUKS_PART")"
    export LUKS_UUID

    echo "$BTRFS_UUID"
    echo "$LUKS_UUID"
}

main() {
    ./lib/stage_disk.sh
    echo "Disk Configuration Done!"
    sleep 3

    echo "Obtaining Disk UUIDs..."
    get_disk_uuid
    echo "Disk UUIDs Got!"
    sleep 3

    ./lib/stage_encryption.sh
    echo "Encryption Done!"
    sleep 3

    echo "Obtaining Encryption UUIDs..."
    get_encryption_uuid
    echo "UUIDs Got!"
    sleep 3

    ./lib/stage_format_and_subvol.sh
    echo "Format and Subvol Creation Done!"
    sleep 3

    ./lib/stage_base_install.sh
    echo "Base Install Done!"
    sleep 3
    
    ./lib/stage_swap_zram.sh
    echo "SWAP and ZRAM Creation Done!"
    sleep 3

    ./lib/stage_localization.sh
    echo "Localization Done"
    sleep 3

    ./lib/stage_user_root.sh
    echo "User Creation Done!"
    sleep 3

    ./lib/stage_services.sh
    echo "Service Activation Done!"
    sleep 3

    ./lib/stage_grub.sh
    echo "GRUB Configuration Done!"
    sleep 3

    ./lib/stage_initramfs.sh
    echo "Initramfs Configuration Done!"
    sleep 3

    echo "Finished: $(date +%Y-%m-%d-%I:%M%p)"
    sleep 3

    local message

    message=("If you need to configure a bit more"
             "do 'arch-chroot /mnt' to access your installation."
             "Then you perform your additional setup")
            
    for line in  "${message[@]}"; do
        echo "$line"
        sleep 0.5s
    done
}

read -rp "Enter choice (Y/N): " choice

case "$choice" in
    [Yy])
        echo "Starting..."
        source user_conf.sh
        sleep 3
        main
    ;;
    [Nn])
        echo "Exiting..."
        exit 0
    ;;
    *)
        echo "Invalid"
        exit 1
esac