# Hostname & Hosts

> The guide will use `arch` as the hostname

Set the machine hostname:

```ini
# /etc/hostname
arch
```

Configure the host file:

```ini
# /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch.localdomain  arch
```
