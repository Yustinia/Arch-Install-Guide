# Installing Packages

Install the necessary packages using `pacstrap`:

```bash
pacstrap -K /mnt \
    base linux-zen linux-zen-headers base-devel linux-firmware \
    git efibootmgr grub iwd networkmanager \
    btrfs-progs vim cryptsetup zram-generator openresolv
```

Generate the filesystem table & chroot:

```bash
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```
