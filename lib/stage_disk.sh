#!/bin/bash

wipefs -af ${DISK}

parted --script "${DISK}" mklabel gpt

parted --script "${DISK}" mkpart ESP fat32 1MiB 1GiB
parted --script "${DISK}" set 1 esp on

parted --script "${DISK}" mkpart primary 1GiB 100%

export EFI_PART="${DISK}1"
export ROOT_PART="${DISK}2"

