# 5G Modem All-in-One Management Plugin (modem-5g)

**By 有房大佬** | **Organized by AAYY兄** | **For Testing Only**

[English](README_EN.md) | [中文](README.md)

For ImmortalWrt / OpenWRT | ARM64 (aarch64_generic) | Quectel RM520N-GL and Full Series 5G Modems

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

## Features

| Component | Description | Port |
|-----------|-------------|------|
| **modemserver** | Go + Vue.js Web Management Interface | 8080 |
| **quectel-CM-M** | Quectel Official QMI Dial-up Manager | — |
| **sendat** | AT Command Tool | — |
| **tom_modem** | Modem Diagnostics & Management Tool | — |

### Core Capabilities

- ✅ QMI WWAN Driver Auto-Binding
- ✅ Auto 5G Dial-up on Boot (IPv4)
- ✅ Web UI Modem Management (Signal/Carrier/Traffic)
- ✅ USB Hot-swap Auto Detection (plug-in starts, unplug stops)
- ✅ AT Command Interaction (signal/carrier/cell/restart)
- ✅ Process Guardian (auto restart on crash)

---

## Supported Modems

| Brand | Model | VID:PID | Status |
|-------|-------|---------|--------|
| Quectel | RM520N-GL | 2c7c:0801 | ✅ Tested |
| Quectel | RM520N-GL | 2c7c:0900 | ⬜ Untested |
| Quectel | Others | 2c7c:030a | ⬜ Untested |

>理论上所有使用 QMI 协议的 Quectel 5G/4G 模组均支持。 / All Quectel 5G/4G modems using QMI protocol should be supported.

---

## Hardware Requirements

- **Router**: ImmortalWrt 23.05.3 / OpenWRT 23.05+
- **Architecture**: ARM64 (aarch64_generic)
- **USB**: USB 3.0 port (recommended)
- **Modem**: Quectel 5G modem (USB mode)

---

## Directory Structure

```
modem-5g/
├── Makefile                      # OpenWRT IPK build file
├── README.md                     # Chinese version
├── README_EN.md                 # This file
├── modem-5g-v1.0.0.zip     # Complete installation package
├── install.sh                   # One-click install script
├── uninstall.sh                 # Uninstall script
│
├── .github/
│   └── workflows/
│       └── build.yml            # GitHub Actions auto build
│
├── luasrc/                      # LuCI Web Interface
│   ├── controller/admin/
│   │   └── modemsrv.lua
│   ├── model/network/
│   │   └── proto_modemmanager.lua
│   └── view/modemsrv/
│       ├── 5Gmodem.htm
│       └── 5Gmodeminfo.htm
│
├── root/etc/                    # System config files
│   ├── init.d/
│   │   ├── usbmode
│   │   ├── modemserver
│   │   └── modemsrv_helper
│   ├── hotplug.d/usb/
│   │   └── 20-modem_mode
│   └── rc.d/
│       ├── S20usbmode
│       ├── S99modemserver
│       └── S99modemsrv
│
└── files/usr/bin/               # Binary programs
    ├── modemserver
    ├── quectel-CM-M
    ├── sendat
    └── tom_modem
```

---

## Auto-Start Logic

```
┌─────────────────────────────────────────────────────┐
│  Layer 1: System Boot                                │
│  /etc/rc.d/S20usbmode  (START=20)                │
│    → Detect Quectel modem VID:PID                   │
│    → Ensure wwan0 exists and is UP                │
│                                                       │
│  /etc/rc.d/S99modemsrv  (START=99)               │
│    → Start quectel-CM-M -s cmnet                  │
│                                                       │
│  /etc/rc.d/S99modemserver (START=99)              │
│    → Start modemserver (Web UI, port 8080)        │
└───────────────────────────┬───────────────────────────┘
                            │  USB Plug/Unplug
                            ▼
┌─────────────────────────────────────────────────────┐
│  Layer 2: USB Hotplug                              │
│  /etc/hotplug.d/usb/20-modem_mode                │
│    → Quectel detected → Start dial-up              │
│    → Unplug → Disconnect                           │
└─────────────────────────────────────────────────────┘
```

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

## Usage

### Web Management Interface

- **Direct Access**: http://192.168.1.1:8080
- **Via LuCI**: Network → 5G Modem → 综合平台

### AT Command Examples

```bash
# Query signal strength
sendat /dev/ttyUSB2 AT+CSQ

# Query carrier info
sendat /dev/ttyUSB2 AT+COPS?

# Query cell info
sendat /dev/ttyUSB2 AT+CGNINFO

# Restart modem
sendat /dev/ttyUSB2 AT+CFUN=1,1
```

### Service Management

```bash
# Check service status
ps | grep -E "modemserver|quectel-CM"

# Check network interface
ip addr show wwan0

# Check logs
logread | grep -E "usbmode|modem|hotplug" | tail -20

# Restart services
/etc/init.d/modemserver restart
/etc/init.d/modemsrv_helper start
```

---

## Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh
```

---

## FAQ

**Q: Modem plugged in but quectel-CM not connecting?**
```bash
lsusb | grep 2c7c
ip link show wwan0
/etc/init.d/modemsrv_helper start
```

**Q: modemserver Web page not accessible?**
```bash
netstat -tlnp | grep 8080
ps | grep modemserver
logread | grep modemserver | tail -10
```

**Q: How to verify dial-up success?**
```bash
ip addr show wwan0
ip route | grep wwan0
ping -I wwan0 8.8.8.8
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
- Organized by AAYY兄

---

## Credits

- **Original Developer**: 有房大佬 — Core technical contributor
- **Organized by**: AAYY兄 [www.aayy.top](http://www.aayy.top)

---

## License

GPL-3.0
