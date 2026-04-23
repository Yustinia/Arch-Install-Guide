# Installing Packages

Install the necessary packages using `basestrap`:

```bash
basestrap -K /mnt \
    base linux-zen linux-zen-headers base-devel linux-firmware dinit elogind-dinit \
    git efibootmgr grub iwd iwd-dinit networkmanager networkmanager-dinit \
    btrfs-progs vim cryptsetup cryptestup-dinit zramen openresolv
```

Generate the filesystem table & chroot:

```bash
fstabgen -U /mnt >> /mnt/etc/fstab
artix-chroot /mnt
```
