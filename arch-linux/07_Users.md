# User Setup

Set the **root** password first:

```bash
passwd
```

Then create your user/s:

```bash
useradd -mG wheel -s /bin/bash yustinia
passwd yustinia
```

> Replace **yustinia** with your desired username

Grant the wheel group with `sudo` permissions:

```bash
EDITOR=vim visudo
```

Locate and uncomment the following line:

```ini
%wheel ALL=(ALL:ALL) ALL
```
