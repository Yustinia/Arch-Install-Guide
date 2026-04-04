# Swap & Zram

> All commands at this point on assumes that you have chrooted

## BTRFS Swapfile

Disable CoW on `/swap`:

```bash
chattr +C /swap
```

Then create the swapfile:

```bash
btrfs filesystem mkswapfile --size 4G --uuid clear /swap/swapfile
```

> You may allocate whatever amount you like for swap

Add the entry to fstab:

```ini
# /etc/fstab
...
/swap/swapfile      none        swap        default     0 0
```

## ZRAM

> This assumes that you have `zram-generator` installed

Add the followig content inside `/etc/systemd/zram-generator.conf.d/zram.conf`:

```ini
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
```

> To allocate 65% of ram, change `ram / 2` to `ram * 0.65`
