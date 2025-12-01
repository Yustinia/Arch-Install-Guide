# Usage README

This the steps on how to use the installation script. Take note that these are my personal defaults.

## The Defaults

Inside the `main.sh` file, is the actual script, inside it you will edit the default variables.

For instance the `DISK=/dev/sda` global variable in which you must set to your actual block id; otherwise, leave it the same if it's similar.

## Install & Usage

1. Boot into the Arch Live ISO and execute the following commands.

```bash
pacman-key --init && pacman-key --populate
pacman -Sy --noconfirm --needed git
git clone https://github.com/Yustinia/Arch-Install-Guide.git (or) https://gitlab.com/Yustinia/arch-install-guide.git
cd arch-install-guide
```

2. Edit the variables that you need inside the `main.sh` file.

3. Give execute permissions using `chmod +x main.sh`.

4. Execute the script using `./main.sh`.

## The Process

1. First wipes and initializes the disk set by the `DISK` variable inside `main.sh`. Ensure that you **assign the correct block** to avoid an accidental wipe.

2. Then it creates 2 partitions, the boot and main/root partition.

3. Encrypts the root partition, provide a password.

4. Formats the partitions and creates subvolumes following the template set in the script.

5. Installs the minimum packages for base installation.

6. Creates a SWAP file and ZRAM.

7. Configures the localization.

8. Provide a root and user password. User creation is defined by the `USERNAME` variable inside the script.

9. Enables services.

10. Configures GRUB and Initramfs, finally generates them.

> Please do know that you can add more configurations inside the script as you wish, as this is my own personal script.
