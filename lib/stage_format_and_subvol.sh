#!/bin/bash

mkfs.fat -F32 "${EFI_PART}"
fatlabel "${EFI_PART}" "ESP"

mkfs.btrfs -L "MAIN" "${LUKS_PART}"

# create subvolumes
mount "${LUKS_PART}" /mount

btrfs subvolume create /mnt/@

subvolume_list=("@home"
                "@var_log"
                "@var_cache"
                "@var_tmp"
                "@tmp"
                "@snapshots"
                "@swap")

for subvol in "${subvolume_list[@]}"; do
    btrfs subvolume create /mnt/"$subvol"
    echo "Created subvolume at /mnt/$subvol"
done

# mount subvolumes
umount -R /mnt

mount -o noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ "${LUKS_PART}" /mnt
mount --mkdir -o subvol=@home "${LUKS_PART}" /mnt/home
mount --mkdir -o subvol=@var_log "${LUKS_PART}" /mnt/var/log
mount --mkdir -o subvol=@var_cache "${LUKS_PART}" /mnt/var/cache
mount --mkdir -o subvol=@var_tmp "${LUKS_PART}" /mnt/var/tmp
mount --mkdir -o subvol=@tmp "${LUKS_PART}" /mnt/tmp
mount --mkdir -o subvol=@snapshots "${LUKS_PART}" /mnt/.snapshots
mount --mkdir -o subvol=@swap "${LUKS_PART}" /mnt/swap
mount --mkdir "${EFI_PART}" /mnt/boot

chattr +C /mnt/swap

echo "Successfully mounted subvolumes!"
