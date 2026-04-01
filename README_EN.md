# 5G Modem All-in-One Management Plugin (modem-5g)

**By YouFang Developer** | **Organized by AAYY兄** | **For Testing Only**

[中文](README.md) | [English](README_EN.md)

For ImmortalWrt / OpenWRT | ARM64 (aarch64_generic) | Quectel RM520N-GL and Full Series 5G Modems

---

## Quick Navigation

| Document | Description |
|----------|-------------|
| [modem-5g-v1.0.0.zip](modem-5g-v1.1.3.zip) | **Complete installation package (Recommended)** |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | **Troubleshooting Manual** — All known issues, causes, solutions, complete file paths, permissions |

> 💡 **Give TROUBLESHOOTING.md to any AI to quickly diagnose and solve problems**

---

## Disclaimer

> ⚠️ **For Learning and Testing Only**
>
> This plugin is organized and provided by [AAYY兄 www.aayy.top](http://www.aayy.top) through reverse engineering, solely for technical research and testing purposes.
>
> All technical content in this plugin comes from publicly available sources and belongs to the original developers. If there is any infringement, please contact us for immediate removal.
>
> **Prohibited for any commercial or illegal use.**

---

## Execution Logic (How It Works)

### Boot Sequence (Layer 1 — System Init)

```
Router boots
  ↓
S20usbmode (START=20)
  → Detects USB device VID:PID = 2C7C:0801
  → Waits for /dev/wwan0 to appear
  → Ensures wwan0 is UP
  ↓
S99modemsrv (START=99)
  → Launches quectel-CM-M -s cmnet & (background dial-up)
  ↓
S99modemserver (START=99)
  → Launches modemserver Web UI (port 8080)
```

### USB Hotplug Sequence (Layer 2 — Dynamic)

```
USB modem plugged in
  → Kernel detects VID:PID → triggers hotplug event
  → /etc/hotplug.d/usb/20-modem_mode runs
    → Verifies VID:PID (2c7c:0801/0900/030a)
    → Ensures wwan0 exists and is UP
    → Launches quectel-CM-M -s cmnet & (background dial-up)

USB modem unplugged
  → Hotplug event fires → connection terminated
```

### Dial-Up Connection Flow

```
quectel-CM-M reads /etc/config/modem (APN: cmnet)
  → Initiates dial-up via QMI protocol
  → Router obtains IP on wwan0 (DHCP)
  → Network traffic routes through wwan0 interface
```

### Web UI Access Flow

```
Browser → http://192.168.1.1:8080
  → modemserver (Go backend) reads ModemData.db (SQLite)
  → Queries modem status via AT commands (/dev/ttyUSB2)
  → Vue.js frontend renders status dashboard
```

---

## Features

| Component | Description | Port |
|-----------|-------------|------|
| **modemserver** | Go + Vue.js Web Management Interface | 8080 |
| **quectel-CM-M** | Quectel Official QMI Dial-up Connection Manager | — |
| **sendat** | AT Command Sending Tool | — |
| **tom_modem** | Modem Diagnostics & Management Tool | — |

### Core Capabilities

- ✅ QMI WWAN Driver Auto-Binding
- ✅ Auto 5G Dial-up on Boot (IPv4)
- ✅ Web UI Modem Management (Signal/Carrier/Traffic monitoring)
- ✅ USB Hot-swap Auto Detection (plug-in starts, unplug stops)
- ✅ AT Command Interaction (signal/carrier/cell info/restart)
- ✅ Process Guardian (automatic restart on abnormal exit)

---

## Supported Modems

| Brand | Model | VID:PID | Status |
|-------|-------|---------|--------|
| Quectel | RM520N-GL | 2c7c:0801 | ✅ Tested |
| Quectel | RM520N-GL | 2c7c:0900 | ⬜ Untested |
| Quectel | Others | 2c7c:030a | ⬜ Untested |

> All Quectel 5G/4G modems using QMI protocol should be supported in theory.

---

## Hardware Requirements

- **Router**: ImmortalWrt 23.05.3 / OpenWRT 23.05+
- **Architecture**: ARM64 (aarch64_generic)
- **USB**: USB 3.0 port (recommended)
- **Modem**: Quectel 5G modem in USB mode

---

## Installation

### Method 1: Download Package (Recommended)

Download [modem-5g-v1.0.0.zip](modem-5g-v1.0.0.zip), upload to router `/tmp/`

```bash
cd /tmp
unzip -o modem-5g-v1.0.0.zip
cd modem-5g
chmod +x install.sh
sed -i 's/\r$//' install.sh uninstall.sh 2>/dev/null
./install.sh
```

### Method 2: Git Clone

```bash
git clone https://github.com/a10463981/modem-5g.git /tmp/modem-5g
cd /tmp/modem-5g
chmod +x install.sh && ./install.sh
```

---

## Troubleshooting

### Troublshooting 1: Modem Plugged In But quectel-CM Not Connecting

**Symptoms**: Modem is physically connected but no dial-up occurs.

**Debug Sequence**:
```bash
# Step 1: Check if modem is recognized
lsusb | grep 2c7c

# Step 2: Check if wwan0 interface exists
ip link show wwan0

# Step 3: Check if wwan0 is UP
ip link show wwan0 | grep UP

# Step 4: Manually start dial-up
quectel-CM-M -s cmnet &

# Step 5: Check logs
logread | grep -E 'usbmode|modem|hotplug' | tail -20

# Step 6: Check AT serial port
ls -l /dev/ttyUSB*
```

---

### Troubleshooting 2: Web UI Not Accessible (Port 8080)

**Symptoms**: Cannot access http://192.168.1.1:8080

**Debug Sequence**:
```bash
# Step 1: Check if port 8080 is listening
netstat -tlnp | grep 8080

# Step 2: Check if modemserver process is running
ps | grep modemserver

# Step 3: Restart service
/etc/init.d/modemserver restart

# Step 4: Check firewall
iptables -L -n | grep 8080
```

---

### Troubleshooting 3: Dial-up Succeeds But No Internet

**Symptoms**: wwan0 has IP but ping fails.

**Debug Sequence**:
```bash
# Step 1: Check if wwan0 has IP address
ip addr show wwan0

# Step 2: Check routing table
ip route | grep wwan0

# Step 3: Test connectivity
ping -I wwan0 8.8.8.8

# Step 4: Check DNS
cat /etc/resolv.conf

# Step 5: Verify APN configuration
cat /etc/config/modem

# Step 6: Check SIM card (balance, activation)
```

---

### Troubleshooting 4: Modem Not Recognized on Certain USB Ports

**Root Cause**: USB path is hardcoded in scripts as `/sys/bus/usb/devices/2-1`.

**Solution**:
1. Try plugging into a different USB port
2. Or edit the path in `root/etc/init.d/usbmode` to match your router's USB topology (e.g., change `2-1` to `1-1` or `1-2`)

---

## AT Command Reference

```bash
# Query signal strength (RSSI)
# Normal: 20-31, below 10 = no signal
sendat /dev/ttyUSB2 AT+CSQ

# Query carrier/operator info
sendat /dev/ttyUSB2 AT+COPS?

# Query cell tower info
sendat /dev/ttyUSB2 AT+CGNINFO

# Restart modem
sendat /dev/ttyUSB2 AT+CFUN=1,1
```

---

## Key Paths and Files

### Service Start Priority
`S20usbmode (20)` → `S99modemsrv (99)` → `S99modemserver (99)`

### Key Device Files
| Path | Description |
|------|-------------|
| `/dev/wwan0` | Network interface (dial-up) |
| `/dev/ttyUSB2` | AT command debug port |

### Key Configuration Files
| Path | Description |
|------|-------------|
| `/etc/config/modem` | APN and network config |
| `/etc/init.d/modemsrv_helper` | Auto-dial script |
| `/etc/hotplug.d/usb/20-modem_mode` | USB hotplug handler |
| `/var/opt/memos/ModemData.db` | SQLite database (settings/SMS/users) |

---

## Known Issues & Caveats

> ⚠️ **Must Read Before Deployment**

1. **USB Path Hardcoded**: Scripts use `/sys/bus/usb/devices/2-1`. Different routers have different USB topologies — you may need to change this to `1-1`, `1-2`, etc.

2. **QMI Protocol Only**: This plugin only supports QMI protocol. Does NOT support MBIM/NCM/ECM or other protocols. Ensure your modem is in QMI mode.

3. **APN Hardcoded**: The dial-up script hardcodes `cmnet` (China Mobile). For other carriers, edit `/etc/config/modem`.

4. **Port 8080 Has No Built-in Auth**: The Web UI has no authentication by default. If exposing to the internet, use nginx or Caddy reverse proxy with password protection.

5. **ModemManager Conflict**: The install script automatically stops and disables ModemManager to avoid port conflicts. Be aware of this if you rely on ModemManager.

6. **Data Persistence**: `ModemData.db` uses SQLite. On routers with limited flash write cycles, consider periodic backups. Router reboots may lose data.

7. **ARMv7 Untested**: Pre-built ARMv7 (32-bit) binaries exist but are not thoroughly tested.

---

## Service Management

```bash
# Check service status
ps | grep -E "modemserver|quectel-CM"

# Check network interface
ip addr show wwan0

# Check system logs
logread | grep -E "usbmode|modem|hotplug" | tail -20

# Restart Web UI service
/etc/init.d/modemserver restart

# Restart dial-up service
/etc/init.d/modemsrv_helper start

# Stop all services
/etc/init.d/modemserver stop
/etc/init.d/modemsrv_helper stop
```

---

## Directory Structure

```
modem-5g/
├── Makefile                      # OpenWRT IPK build file
├── README.md                     # Chinese version
├── README_EN.md                  # English version (this file)
├── modem-5g-v1.0.0.zip        # Complete installation package
├── install.sh                    # One-click install script
├── uninstall.sh                  # Uninstall script
│
├── .github/
│   └── workflows/
│       └── build.yml             # GitHub Actions CI/CD auto build
│
├── luasrc/                       # LuCI Web Interface
│   ├── controller/admin/
│   │   └── modemsrv.lua          # LuCI controller
│   ├── model/network/
│   │   └── proto_modemmanager.lua
│   └── view/modemsrv/
│       ├── 5Gmodem.htm
│       └── 5Gmodeminfo.htm
│
├── root/etc/                     # System configuration files
│   ├── init.d/
│   │   ├── usbmode               # USB mode initialization
│   │   ├── modemserver           # Web UI service
│   │   └── modemsrv_helper      # Modem helper service
│   ├── hotplug.d/usb/
│   │   └── 20-modem_mode        # USB hotplug handler
│   └── rc.d/
│       ├── S20usbmode
│       ├── S99modemserver
│       └── S99modemsrv
│
└── files/usr/bin/                # Binary executables
    ├── modemserver               # Web management daemon
    ├── quectel-CM-M             # Quectel QMI manager
    ├── sendat                    # AT command tool
    └── tom_modem                 # Diagnostic tool
```

---

## Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh
```

---

## Changelog

### v1.0.0 (2026-03-25)

- Initial release
- Support Quectel RM520N-GL (2c7c:0801)
- modemserver Web UI (Go + Vue.js, port 8080)
- quectel-CM-M dial-up manager (QMI IPv4)
- sendat / tom_modem AT command tools
- Full LuCI management interface integration
- USB hot-swap auto detection
- Organized and provided by AAYY兄

---

## Credits

- **Original Developer**: YouFang Developer — Core technical contributor
- **Organized and Provided by**: AAYY兄 [www.aayy.top](http://www.aayy.top)

---

## License

GPL-3.0
