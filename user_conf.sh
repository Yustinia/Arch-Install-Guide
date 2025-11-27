#!/bin/bash

# DISKS and PARTS
export DISK="/dev/sda"
export EFI_PART="${DISK}1"
export ROOT_PART="${DISK}2"

# Encryption
export LUKS_NAME="cryptroot"
export LUKS_PART="/dev/mapper/cryptroot"
export ENCRYPTED_UUID=""
export UNENCRYPTED_UUID=""

# BTRFS Configuration
export SUBVOL_ROOT="@"
export SUBVOL_HOME="@home"
export SUBVOL_VAR_LOG="@var_log"
export SUBVOL_VAR_CACHE="@var_cache"
export SUBVOL_VAR_TMP="@var_tmp"
export SUBVOL_TMP="@tmp"
export SUBVOL_SWAP="@swap"
export SUBVOL_SNAPSHOTS="@snapshots"

export BTRFS_SWAP_SIZE="8G"

# System
export HOSTNAME="Arch"
export HOSTS="127.0.1.1 Arch.localdomain Arch"
export USERNAME="myUser"
export TIMEZONE="Asia/Manila"
export LOCALE="en_US.UTF-8 UTF-8"
export LOCALE_CONF="LANG=en_US.UTF-8"
export VCONSOLE="KEYMAP=us"

# ZRAM
export ZRAM_FRACTION="0.6"
export ZRAM_ALGO="zstd"
export ZRAM_PRIO="100"

# Packages
export PACSTRAP_PKGS="base linux-zen linux-firmware linux-zen-headers base-devel efibootmgr grub networkmanager btrfs-progs vim cryptsetup zram-generator"
