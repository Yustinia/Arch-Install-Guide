#!/bin/bash

cryptsetup luksFormat "${ROOT_PART}"
cryptsetup open "${ROOT_PART}" "${LUKS_NAME}"

export EFI_PART="${DISK}1"
export ROOT_PART="${DISK}2"
BTRFS_UUID="$(blkid -o value -s UUID "$ROOT_PART")"
LUKS_UUID="$(blkid -o value -s UUID "$LUKS_PART")"
export BTRFS_UUID
export LUKS_UUID
