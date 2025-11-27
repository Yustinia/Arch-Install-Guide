#!/bin/bash

source "$(pwd)/user_conf.sh"

LIB_DIR="$(pwd)/lib"
LIB_SCRIPTS=("stage_disk.sh" "stage_encryption.sh" "stage_format_and_subvol.sh" "stage_base_install.sh" "stage_localization.sh" "stage_swap_zram.sh")

main() {
    for script in "${LIB_SCRIPTS[@]}"; do
        local script_path="$LIB_DIR/$script"

        bash "$script_path"
    done
}

main
