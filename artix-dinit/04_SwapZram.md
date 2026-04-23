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

> This assumes that you have `zramen` installed

Add the following content inside `/etc/dinit.d/config/zramen.conf`:

```ini
# /etc/dinit.d/config/zramen.conf
ZRAM_SIZE=50              # Percentage of total RAM to allocate (e.g. 50 = 50%)
ZRAM_COMP_ALGORITHM=zstd
ZRAM_PRIORITY=100
```

> To allocate 65% of ram, change 50 to 65

Create `/etc/dinit.d/zramen` to write the following:

```ini
# /etc/dinit.d/zramen
type            = scripted
command         = /usr/bin/zramen make
stop-command    = /usr/bin/zramen toss
smooth-recovery = true
env-file        = /etc/dinit.d/config/zramen.conf
waits-for       = pre-local.target
```

Also comment out the logfile to ensure that zram functions properly:

```ini
# /etc/dinit.d/zramen
# logfile ...
```
