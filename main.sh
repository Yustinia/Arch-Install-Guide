#!/bin/bash

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

source "./user_conf.sh"

main() {
    ./lib/stage_disk.sh || exit 1
    echo "Disk Configuration Done!"
    sleep 3

    ./lib/stage_encryption.sh || exit 1
    echo "Encryption Done!"
    sleep 3

    ./lib/stage_format_and_subvol.sh || exit 1
    echo "Format and Subvol Creation Done!"
    sleep 3

    ./lib/stage_base_install.sh || exit 1
    echo "Base Install Done!"
    sleep 3
    
    ./lib/stage_swap_zram.sh || exit 1
    echo "SWAP and ZRAM Creation Done!"
    sleep 3

    ./lib/stage_localization.sh || exit 1
    echo "Localization Done"
    sleep 3

    ./lib/stage_user_root.sh || exit 1
    echo "User Creation Done!"
    sleep 3

    ./lib/stage_services.sh || exit 1
    echo "Service Activation Done!"
    sleep 3

    ./lib/stage_grub.sh || exit 1
    echo "GRUB Configuration Done!"
    sleep 3

    ./lib/stage_initramfs.sh || exit 1
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
    done
}

main
