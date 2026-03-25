# modem-5g

**5G 模组全能管理插件** — 有房大佬出品

支持 Quectel RM520N-GL 及全系列 Quectel 5G 模组 | 适用于 ImmortalWrt / OpenWRT | ARM64 (aarch64_generic)
<img width="1917" height="1041" alt="企业微信截图_17744270015841" src="https://github.com/user-attachments/assets/b10c05b3-e9f7-4285-884f-02e300787100" />

---

## 目录

- [项目概述](#项目概述)
- [文件结构说明](#文件结构说明)
- [各组件详解](#各组件详解)
- [自动启动逻辑](#自动启动逻辑)
- [安装方式](#安装方式)
- [命令行工具](#命令行工具)
- [编译说明](#编译说明)
- [卸载说明](#卸载说明)
- [常见问题](#常见问题)

---

## 项目概述

本插件为 OpenWRT / ImmortalWrt 系统提供完整的 5G 模组管理能力，包含：

| 组件 | 语言 | 说明 | 端口 |
|------|------|------|------|
| **modemserver** | Go | Web 管理界面（Vue.js 前端） | 8080 |
| **quectel-CM-M** | C | Quectel 官方拨号连接管理器 | — |
| **sendat** | C | AT 命令发送工具 | — |
| **tom_modem** | C | 模组管理工具（重启/诊断） | — |

---

## 截图展示

![5G Modem 管理界面](https://github.com/a10463981/modem-5g/raw/main/docs/screenshot.png)

---

## 文件结构说明

```
modem-5g/
├── Makefile                        # OpenWRT 包编译文件
├── README.md                      # 本文件（项目说明文档）
├── install.sh                     # 一键安装脚本
├── uninstall.sh                   # 卸载脚本
│
├── .github/
│   └── workflows/
│       └── build.yml              # GitHub Actions 自动编译流程
│
├── luasrc/                        # LuCI Web 界面文件
│   │                               # （安装到 /usr/lib/lua/luci/）
│   ├── controller/
│   │   └── admin/
│   │       └── modemsrv.lua       # ⭐ LuCI 控制器（路由菜单入口）
│   │                               #    注册 "网络 → 5G Modem" 菜单
│   │
│   ├── model/
│   │   └── network/
│   │       └── proto_modemmanager.lua
│   │                               # ⭐ 网络协议扩展（让 LuCI 识别 modem 网络接口）
│   │
│   └── view/
│       └── modemsrv/
│           ├── main.htm           # ⭐ 主管理页面（模组控制台 UI）
│           └── status.htm         # ⭐ 状态页面（信号/流量实时监控）
│
├── root/                          # 系统文件（安装到 /）
│   │
│   ├── etc/
│   │   │
│   │   ├── init.d/
│   │   │   ├── modemserver       # ⭐ modemserver 启动脚本
│   │   │   │                      #    - boot 时自动启动 modemserver（Web UI）
│   │   │   │                      #    - 监听端口 8080
│   │   │   │                      #    - 提供 Vue.js 前端资源
│   │   │   │
│   │   │   ├── usbmode           # ⭐ USB 模式切换脚本
│   │   │   │                      #    - 根据模组类型切换 USB 工作模式
│   │   │   │                      #    - QMI / MBIM / NCM / ACM 自适应
│   │   │   │
│   │   │   └── quectel-CM        # ⭐ quectel-CM 拨号管理器
│   │   │                              #    - procd 常驻进程
│   │   │                              #    - 自动建立移动网络连接（IPv4+IPv6）
│   │   │                              #    - 服务异常退出自动重启（respawn）
│   │   │
│   │   ├── hotplug.d/
│   │   │   └── usb/
│   │   │       └── 20-modem_mode  # ⭐ USB 热插拔脚本（核心自动逻辑）
│   │   │                              #    - 插拔 USB 模组时自动检测 Quectel 设备
│   │   │                              #    - 检测到 → 依次启动 quectel-CM + modemserver
│   │   │                              #    - 拔出 → 自动断开 quectel-CM
│   │   │
│   │   ├── rc.d/
│   │   │   ├── S20usbmode        # ⭐ 开机启动链接（usbmode，优先级 20）
│   │   │   ├── K10modemserver    # ⭐ 开机启动链接（modemserver，优先级 10，开机前期启动）
│   │   │   └── S99modemserver    # ⭐ 开机启动链接（modemserver，优先级 99，最后启动）
│   │   │
│   │   ├── config/
│   │   │   └── modem             # ⭐ UCI 配置文件（APN/端口/IPv4/IPv6 等参数）
│   │   │
│   │   ├── ModemData.db          # ⭐ SQLite 缓存（模组状态数据）
│   │   └── usb-mode.json         # ⭐ USB 模式切换配置（Vid/Pid 映射表）
│   │
│   └── CONTROL/                   # （OpenWRT 编译用，非安装文件）
│       └── postinst              #    安装后执行的脚本（设置权限 + 启用服务）
│
└── files/
    └── usr/
        └── bin/
            ├── modemserver       # ⭐ Go 二进制 Web 服务器（11.9MB）
            ├── quectel-CM-M      # ⭐ Quectel 官方拨号工具（196KB）
            ├── sendat             # ⭐ AT 命令发送工具（64KB）
            └── tom_modem          # ⭐ 模组管理工具（64KB）
```

---

## 各组件详解

### 1. modemserver（Web 管理界面）

**路径**: `files/usr/bin/modemserver` + `root/etc/init.d/modemserver`

**功能**: Go 编写的 HTTP 服务器，监听 8080 端口，提供 Vue.js Web 管理界面。

**启动方式**: boot 时通过 rc.d/S99modemserver 自动启动

**端口**: 8080

**访问地址**: `http://192.168.1.1:8080`

**init 脚本逻辑**:
```
boot
  → 检查 /usr/bin/modemserver 是否存在
  → insmod 加载必要内核模块（可选）
  → 启动 modemserver 进程（后台运行）
  → 监听崩溃，自动重启（procd respawn）
```

### 2. quectel-CM-M（拨号连接管理器）

**路径**: `files/usr/bin/quectel-CM-M` + `root/etc/init.d/quectel-CM`

**功能**: Quectel 官方拨号工具，负责建立移动网络数据连接（支持 IPv4 + IPv6）。

**启动方式**: USB 模组插入后由 hotplug 触发，或手动启动

**参数**: `-i usb0 -4 -6 -s cmnet`（接口名 + 双栈 + APN）

**procd 守护**: 服务异常退出后自动重启（respawn 30s 间隔，5次重试后放弃）

### 3. sendat（AT 命令工具）

**路径**: `files/usr/bin/sendat`

**用法**:
```bash
sendat <串口设备> <AT命令>
例：sendat /dev/ttyUSB2 AT+CSQ      # 查询信号强度
例：sendat /dev/ttyUSB2 AT+COPS?   # 查询运营商
例：sendat /dev/ttyUSB2 AT+CFUN=1,1 # 重启模组
```

### 4. tom_modem（模组管理工具）

**路径**: `files/usr/bin/tom_modem`

**功能**: 模组诊断、重启、状态读取等管理操作。

---

## 自动启动逻辑

本插件采用三层启动机制，确保各种场景下模组都能正常工作：

```
┌─────────────────────────────────────────────────────────┐
│  第一层：系统启动（boot）                               │
│                                                         │
│  rc.d/S99modemserver                                   │
│    → /etc/init.d/modemserver start                     │
│      → 启动 modemserver（Web UI，端口 8080）            │
│      → modemserver 常驻运行，异常自动重启                  │
│                                                         │
│  rc.d/S20usbmode                                       │
│    → /etc/init.d/usbmode start                         │
│      → 预加载 USB 模式切换配置                           │
│      → 检测当前已插入的模组，执行初始化                    │
└───────────────────────────┬─────────────────────────────┘
                            │  USB 模组插入
                            ▼
┌─────────────────────────────────────────────────────────┐
│  第二层：USB 热插拔检测（hotplug）                       │
│                                                         │
│  /etc/hotplug.d/usb/20-modem_mode                     │
│                                                         │
│  检测到 Quectel 模组（Vid:Pid = 2c7c:0801 等）         │
│    → /etc/init.d/usbmode start（切换 USB 模式）         │
│    → sleep 2（等待模组就绪）                            │
│    → /etc/init.d/quectel-CM start（建立数据连接）       │
│    → /etc/init.d/modemserver start（启动 Web UI）       │
│                                                         │
│  USB 模组拔出                                           │
│    → /etc/init.d/quectel-CM stop（断开连接）           │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│  第三层：进程守护（procd respawn）                       │
│                                                         │
│  quectel-CM / modemserver 异常退出                     │
│    → procd 检测到进程消失                               │
│    → 30 秒后自动重启服务                                │
│    → 最多重试 5 次                                     │
└─────────────────────────────────────────────────────────┘
```

---

## 安装方式

### 方式一：直接安装 IPK（推荐）

1. 在 GitHub Actions 构建完成后，下载 Artifacts 中的 `modem-5g_1.0.0-1_aarch64_generic.ipk`
2. 上传到路由器 `/tmp/`
3. SSH 执行：
```bash
opkg install /tmp/modem-5g_1.0.0-1_aarch64_generic.ipk --force-overwrite
```

### 方式二：手动安装（适用于任意系统）

```bash
git clone https://github.com/a10463981/modem-5g.git /tmp/modem-5g
cd /tmp/modem-5g
chmod +x install.sh
./install.sh
```

---

## 命令行工具

```bash
# 查看模组 USB 识别情况
lsusb | grep 2c7c

# 查看模组 AT 端口
ls /dev/ttyUSB*

# 发送 AT 命令
sendat /dev/ttyUSB2 AT+CSQ          # 信号强度
sendat /dev/ttyUSB2 AT+COPS?        # 运营商信息
sendat /dev/ttyUSB2 AT+CGNINFO      # 小区信息
sendat /dev/ttyUSB2 AT+CFUN=1,1     # 重启模组

# 查看服务状态
/etc/init.d/modemserver status
/etc/init.d/quectel-CM status

# 手动启停服务
/etc/init.d/modemserver start
/etc/init.d/quectel-CM start
/etc/init.d/quectel-CM stop

# 查看网络接口
ip addr show usb0
logread | grep modem
```

---

## 编译说明

### GitHub Actions（自动编译，推荐）

1. 推送代码到 `master` 分支，自动触发构建
2. 访问 https://github.com/a10463981/modem-5g/actions 下载 Artifacts
3. 下载 `ipk-packages` 中的 ipk 文件

### 本地编译（需要 OpenWRT SDK）

```bash
# 1. 下载 ImmortalWrt SDK
wget https://downloads.immortalwrt.org/releases/23.05.3/targets/rockchip/armv8/immortalwrt-sdk-23.05.3-rockchip-armv8_gcc-12.3.0_musl.Linux-x86_64.tar.xz
tar xf immortalwrt-sdk-*.tar.xz
cd immortalwrt-sdk-*

# 2. 链接本仓库
ln -s /path/to/modem-5g package/modem-5g

# 3. 安装依赖
./scripts/feeds update -a
./scripts/feeds install -a -p luci

# 4. 编译
echo 'CONFIG_PACKAGE_modem-5g=y' >> .config
make defconfig
make -j$(nproc) package/modem-5g/compile
```

---

## 卸载说明

### 自动卸载

```bash
chmod +x uninstall.sh
./uninstall.sh
```

### 手动卸载

```bash
# 停止服务
/etc/init.d/modemserver stop
/etc/init.d/quectel-CM stop

# 禁用开机启动
/etc/init.d/modemserver disable
/etc/init.d/quectel-CM disable

# 删除文件
rm -f /usr/bin/modemserver /usr/bin/quectel-CM-M /usr/bin/sendat /usr/bin/tom_modem
rm -f /etc/init.d/modemserver /etc/init.d/usbmode /etc/init.d/quectel-CM
rm -f /etc/hotplug.d/usb/20-modem_mode
rm -f /etc/config/modem /etc/ModemData.db /etc/usb-mode.json
rm -f /usr/lib/lua/luci/controller/modemsrv.lua
rm -f /usr/lib/lua/luci/model/network/proto_modemmanager.lua
rm -rf /usr/lib/lua/luci/view/modemsrv
rm -f /etc/rc.d/S99modemserver /etc/rc.d/S20usbmode /etc/rc.d/S99quectelCM
```

---

## 常见问题

**Q: 模组已插入但 quectel-CM 没有自动连接？**
```bash
# 检查 USB 是否识别
lsusb | grep 2c7c

# 检查 hotplug 是否触发
logread | grep hotplug-modem

# 手动启动测试
/etc/init.d/quectel-CM start
```

**Q: modemserver Web 页面打不开？**
```bash
# 检查端口监听
netstat -tlnp | grep 8080

# 检查进程状态
/etc/init.d/modemserver status
ps | grep modemserver

# 查看启动日志
logread | grep modemserver
```

**Q: 如何查看拨号是否成功？**
```bash
# 查看网络接口
ip addr show usb0

# 查看路由
ip route | grep usb0

# 查看 DNS
cat /etc/resolv.conf
```

---

## 致谢

**有房大佬** — 核心技术贡献者

---

## 更新日志

### v1.0.0 (2026-03-25)
- 初始版本
- 支持 Quectel RM520N-GL
- modemserver Web UI（Go + Vue.js，端口 8080）
- quectel-CM-M 拨号管理（IPv4 + IPv6 双栈）
- sendat / tom_modem AT 命令工具
- 完整 LuCI 管理界面
- USB 热插拔自动检测（插入启动，拔出停止）
- procd 进程守护（异常自动重启）
- 三层启动机制（boot + hotplug + respawn）

---

## 许可证

GPL-3.0
