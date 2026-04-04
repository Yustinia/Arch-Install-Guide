# Setting up Connection

Use `iwctl` to setup **wireless** connection. Otherwise, if you are on **ethernet**, skip this step:

```bash
iwctl station list                        # 1. Find your wireless station name
iwctl station wlan0 scan                  # 2. Scan for nearby networks
iwctl station wlan0 get-networks          # 3. List discovered networks
iwctl station wlan0 connect <ssid>        # 4. Connect (replace <ssid> with your network name)
ping -c 3 archlinux.org                   # 5. Verify connectivity
```
