# GRUB and Initramfs

First retrieve the UUID for `/dev/nvme0n1p3`:

```bash
blkid -o value -s UUID /dev/nvme0n1p3
```

The UUID will be used for GRUB

## Configuring GRUB

With the UUID retrieved, push to `/etc/default/grub`:

```bash
blkid -o value -s UUID /dev/nvme0n1p3 >> /etc/default/grub
```

Inside `/etc/default/grub`, add the following parameters:

```ini
# /etc/default/grub
...
GRUB_CMDLINE_LINUX_DEFAULT="... cryptdevice=UUID=<UUID>:encrypted root=/dev/mapper/encrypted"
...
```

> Do not remove nor replace existing parameters

Uncomment CRYPTODISK:

```ini
...
GRUB_ENABLE_CRYPTODISK=y
...
```

## Installing GRUB

> If you have not removed the UUID entry at the bottom of `/etc/default/grub`, remove it to avoid any errors

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## Configuring initramfs

Open `/etc/mkinitcpio.conf` to make the following changes:

```ini
MODULES=(btrfs)

HOOKS=(... block encrypt filesystems ...)
```

Regenerate the initramfs:

```bash
mkinitcpio -P
```
