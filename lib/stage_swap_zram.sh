#!/bin/bash

mkdir -pv /mnt/etc/systemd/zram-generator.conf.d

cat > /mnt/etc/systemd/zram-generator.conf.d/zram.conf <<EOF
[zram0]
zram-size = ram * ${ZRAM_FRACTION}
compression-algorithm = ${ZSTD_ALGO}
swap-priority = ${ZRAM_PRIO}
EOF

btrfs filesystem mkswapfile --size "${BTRFS_SWAP_SIZE}" --uuid clear /mnt/swap/swapfile
chattr +C /mnt/swap/swapfile

echo "/swap/swapfile none swap default 0 0" >> /mnt/etc/fstab

echo "Successfully created ZRAM and SWAP"
