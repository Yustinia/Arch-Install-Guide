# LUKS Key

> This avoids the tedious process of proving the passphrase on every boot

First generate the key onto `/etc`:

> You may choose `urandom` or `random` however you like

```bash
dd if=/dev/urandom of=/etc/encrypted.key bs=64 count=1
```

Add the key to LUKS:

```bash
crypsetup luksAddKey /dev/nvme0n1p3 /etc/encrypted.key
```

Edit GRUB to include the key:

```ini
# /etc/default/grub
...
GRUB_CMDLINE_LINUX_DEFAULT="... cryptdevice=<UUID>:encrypted cryptkey=rootfs:/etc/encrypted.key root=/dev/mapper/encrypted"
...
```

Configure initramfs to include the key:

```ini
# /etc/mkinitcpio.conf
FILES=(... /etc/encrypted.key ...)
```

Finally regenerate GRUB & initramfs:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
mkinitcpio -P
```
