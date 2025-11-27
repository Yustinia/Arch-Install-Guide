#!/bin/bash

sed -i "/^# *${LOCALE}$/s/^# *//" /mnt/etc/locale.gen

echo "${LOCALE_CONF}" >> /mnt/etc/locale.conf

echo "${VCONSOLE}" >> /mnt/etc/vconsole.conf

echo "${HOSTS}" >> /mnt/etc/HOSTS

echo "${HOSTNAME}" >> /mnt/etc/hostname
