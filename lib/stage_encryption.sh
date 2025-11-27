#!/bin/bash

cryptsetup luksFormat "${ROOT_PART}"
cryptsetup open "${ROOT_PART}" "${LUKS_NAME}"

export BTRFS_UUID="$(blkid -o value -s UUID $ROOT_PART)"
export LUKS_UUID="$(blkid -o value -s UUID $LUKS_PART)"
