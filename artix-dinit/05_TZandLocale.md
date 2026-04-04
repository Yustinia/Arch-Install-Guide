# Timezone & Locale

Identify the continent & city

## Timezone Setup

```bash
ln -sf /usr/share/zoneinfo/<continent>/<city> /etc/localtime
hwclock --systohc
```

## Locale Setup

> This guide with use US English

Open `/etc/locale.gen` & uncomment:

```ini
# /etc/locale.gen

...
en_US.UTF-8 UTF-8
...
```

Then generate the locale:

```bash
locale-gen
```

Set the locale:

```bash
# /etc/locale.conf
LANG=en_US.UTF-8
```
