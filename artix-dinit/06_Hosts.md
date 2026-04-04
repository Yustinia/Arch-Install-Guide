# Hostname & Hosts

> The guide will use `artix` as the hostname

Set the machine hostname:

```ini
# /etc/hostname
artix
```

Configure the host file:

```ini
# /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   artix.localdomain  artix
```
