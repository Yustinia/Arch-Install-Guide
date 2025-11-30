#!/bin/bash

check_root_user() {
    if [[ $EUID -ne 0 ]]; then
        echo "Not the root user"
        exit 1
    fi
}

# set variables below
# DISKS and PARTS
DISK="/dev/sda"

# Encryption
LUKS_NAME="cryptroot"
LUKS_PART="/dev/mapper/cryptroot"

BTRFS_SWAP_SIZE="8G"

# System
HOSTNAME="Arch"
HOSTS="127.0.1.1 Arch.localdomain Arch"
USERNAME="myUser"
TIMEZONE_CONT="Asia"
TIMEZONE_CITY="Manila"
# LOCALE="en_US.UTF-8 UTF-8"
LOCALE_CONF="LANG=en_US.UTF-8"
VCONSOLE="KEYMAP=us"

# ZRAM
ZRAM_FRACTION="0.6"
ZRAM_ALGO="zstd"
ZRAM_PRIO="100"


stage_disk() {
    wipefs -af "${DISK}"

    parted --script "${DISK}" mklabel gpt

    parted --script "${DISK}" mkpart ESP fat32 1MiB 1GiB
    parted --script "${DISK}" set 1 esp on

    parted --script "${DISK}" mkpart primary 1GiB 100%
}

get_disk_uuid() {
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
}

stage_encryption() {
    cryptsetup luksFormat "${ROOT_PART}"
    cryptsetup open "${ROOT_PART}" "${LUKS_NAME}"
}

get_encryption_uuid() {
    BTRFS_UUID="$(blkid -o value -s UUID "${ROOT_PART}")"
    LUKS_UUID="$(blkid -o value -s UUID "${LUKS_PART}")"
}

stage_format_and_subvol() {
    mkfs.fat -F32 "${EFI_PART}"
    fatlabel "${EFI_PART}" "ESP"

    mkfs.btrfs -f -L "MAIN" "${LUKS_PART}"

    # create subvolumes
    mount "${LUKS_PART}" /mnt

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
}

stage_base_install() {
    pacstrap -K /mnt base linux-zen linux-firmware linux-zen-headers base-devel efibootmgr grub networkmanager btrfs-progs vim cryptsetup zram-generator

    genfstab -U /mnt >> /mnt/etc/fstab
}

stage_swap_zram() {
    mkdir -pv /mnt/etc/systemd/zram-generator.conf.d

    echo "[zram0]" > /mnt/etc/systemd/zram-generator.conf.d/zram.conf
    echo "zram-size = ram * ${ZRAM_FRACTION}" >> /mnt/etc/systemd/zram-generator.conf.d/zram.conf
    echo "compression-algorithm = ${ZRAM_ALGO}" >> /mnt/etc/systemd/zram-generator.conf.d/zram.conf
    echo "swap-priority = ${ZRAM_PRIO}" >> /mnt/etc/systemd/zram-generator.conf.d/zram.conf

    btrfs filesystem mkswapfile --size "${BTRFS_SWAP_SIZE}" --uuid clear /mnt/swap/swapfile
    chattr +C /mnt/swap/swapfile

    echo "/swap/swapfile none swap default 0 0" >> /mnt/etc/fstab
}

stage_localization() {
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE_CONT"/"$TIMEZONE_CITY" /etc/localtime
    arch-chroot /mnt hwclock --systohc

    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
    echo "${LOCALE_CONF}" >> /mnt/etc/locale.conf
    echo "${VCONSOLE}" >> /mnt/etc/vconsole.conf
    echo "${HOSTS}" >> /mnt/etc/hosts
    echo "${HOSTNAME}" >> /mnt/etc/hostname

    arch-chroot /mnt locale-gen
}

stage_user_root() {
    arch-chroot /mnt passwd

    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "${USERNAME}"

    arch-chroot /mnt passwd "${USERNAME}"

    sed -i '/^#\s*%wheel\s\+ALL=(ALL:ALL)\s\+ALL/s/^#\s*//' /mnt/etc/sudoers
}

stage_services() {
    arch-chroot /mnt systemctl enable NetworkManager

    echo "Enabled NetworkManager"
}

stage_grub() {
    local CRYPT_PARAMS
    CRYPT_PARAMS="rd.luks.name=${BTRFS_UUID}=${LUKS_NAME} root=${LUKS_PART}"

    sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s|\"$| ${CRYPT_PARAMS}\"|" /mnt/etc/default/grub

    sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /mnt/etc/default/grub

    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

stage_initramfs() {
    arch-chroot /mnt sed -i 's/^MODULES=.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf

    arch-chroot /mnt sed -i 's/\(block\)/\1 sd-encrypt/' /etc/mkinitcpio.conf

    arch-chroot /mnt mkinitcpio -P
}

main() {

    check_root_user

    welcome_msg=("This is an Arch Install script"
                 "Configure the defaults via the user_conf.sh file"
                 "If you like this script, please leave a star on the repo!"
                 "Thank you!")

    for line in "${welcome_msg[@]}"; do
        echo "$line"
        sleep 0.5s
    done

    read -rp "Enter choice (Y/N): " choice

    case "$choice" in
        [Yy])
            echo "Starting..."

            stage_disk
            get_disk_uuid

            echo "EFI:  $EFI_PART"
            echo "ROOT: $ROOT_PART"

            stage_encryption
            get_encryption_uuid

            echo "BTRFS:    $BTRFS_UUID"
            echo "LUKS:     $LUKS_UUID"

            stage_format_and_subvol
            stage_base_install
            stage_swap_zram
            stage_localization
            stage_user_root
            stage_services
            stage_grub
            stage_initramfs
        ;;
        [Nn])
            echo "Exiting..."
            exit 0
        ;;
        *)
            echo "Invalid!"
            exit 1
    esac

    end_message=("If you need to configure a bit more"
                 "do 'arch-chroot /mnt' to access your installation."
                 "Then you perform your additional setup")
            
    for line in  "${end_message[@]}"; do
        echo "$line"
        sleep 0.5s
    done

    echo "Finished: $(date +%Y-%m-%d-%I:%M%p)"

    exit 0
}