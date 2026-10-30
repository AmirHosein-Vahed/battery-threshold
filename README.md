# Battery Charge Threshold Manager

A lightweight, dependency-free Bash script to automatically detect and configure battery charging start and end thresholds on Linux systems via `/sys/class/power_supply/BAT*`.

Setting charging thresholds (e.g., starting at 40% and stopping at 80%) helps prevent lithium-ion battery degradation and extends overall battery lifespan—especially for laptops that remain plugged into AC power for extended periods.

---

## Features

- **Automatic Detection:** Scans `/sys/class/power_supply/BAT*` to locate all connected batteries (`BAT0`, `BAT1`, etc.) and verifies hardware/kernel support.
- **Safe Write Ordering:** Automatically checks the current `end_threshold` before applying new values to prevent Linux kernel `Invalid argument` write errors (which occur if you try to set a `start_threshold` higher than the currently active `end_threshold`).
- **Input Validation:** Ensures thresholds are valid integers between `0` and `100` and that `START < END`.
- **Read-Only Status Mode:** View current battery thresholds without requiring `sudo` privileges.

---

## Prerequisites

- **OS:** Linux with kernel support for `charge_control_start_threshold` and `charge_control_end_threshold` (common on ThinkPads, ASUS, Huawei, Framework, Dell, and other laptops via vendor ACPI modules like `thinkpad_acpi` or `asus-nb-wmi`).
- **Privileges:** `sudo` access is required to modify threshold values (not required for `--status`).

---

## Installation

1. Clone or download the script as `battery-threshold.sh`:
   ```bash
   chmod +x battery-threshold.sh
   ```

2. *(Optional)* Move it to `/usr/local/bin` for system-wide access:
   ```bash
   sudo mv battery-threshold.sh /usr/local/bin/battery-threshold
   ```

---

## Usage

```text
Usage: battery-threshold.sh [OPTIONS] [START_THRESHOLD] [END_THRESHOLD]

Arguments:
  START_THRESHOLD   Start charging below this % (default: 40)
  END_THRESHOLD     Stop charging at this % (default: 80)

Options:
  -s, --status      Display current battery thresholds without modifying them
  -h, --help        Show this help message
```

### Examples

**1. Apply default thresholds (40% start, 80% end):**
```bash
./battery-threshold.sh
```

**2. Apply custom thresholds (e.g., 50% start, 85% end):**
```bash
./battery-threshold.sh 50 85
```

**3. Check current thresholds (no `sudo` required):**
```bash
./battery-threshold.sh --status
```

**Sample Output:**
```text
=== Battery: BAT0 ===
Applying thresholds (Start: 40%, End: 80%)...
  Start Threshold : 40%
  End Threshold   : 80%
```

---

## Making Thresholds Persistent Across Reboots

On some systems, `/sys/class/power_supply/` values reset after a reboot or hibernation. You can automate this script on boot using a `systemd` service:

1. Ensure the script is installed at `/usr/local/bin/battery-threshold`:
   ```bash
   sudo cp battery-threshold.sh /usr/local/bin/battery-threshold
   sudo chmod +x /usr/local/bin/battery-threshold
   ```

2. Create a systemd unit file at `/etc/systemd/system/battery-threshold.service`:
   ```ini
   [Unit]
   Description=Set Battery Charge Thresholds
   After=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/battery-threshold 40 80
   RemainAfterExit=yes

   [Install]
   WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
   ```

3. Enable and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now battery-threshold.service
   ```

---

## Troubleshooting

- **`Error: Found battery (...), but charge threshold files are not supported by your kernel/hardware.`**
  Your laptop's vendor ACPI kernel module may not be loaded, or your hardware only supports a single end threshold (`charge_control_end_threshold`). Check `ls /sys/class/power_supply/BAT*` to verify which files exist on your machine.
- **`tee: ...: Invalid argument`**
  Some laptops only accept specific threshold increments (for example, 60% or 80% only on certain IdeaPad/ASUS models) or do not allow `start_threshold` to be too close to `end_threshold`. Try standard values like `40 80` or `60 80`.

---

## License

MIT License
