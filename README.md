# 5G模组全能管理插件（modem-5g）

**有房大佬出品** | **AAYY兄 整理提供** | 仅供测试研究

适用于 ImmortalWrt / OpenWRT | ARM64 (aarch64_generic) | Quectel RM520N-GL 及全系列 5G 模组

---

## 免责声明

> ⚠️ **仅供学习与测试使用**
>
> 本插件由 [AAYY兄 www.aayy.top](http://www.aayy.top) 整理反编译提供，仅限于技术研究与测试目的。
>
> 本插件涉及的所有技术内容均来自公开渠道，版权归原始开发者所有。如有任何侵权行为，请及时联系，将在第一时间删除处理。
>
> **禁止用于任何商业用途或非法用途。**

---

## 功能特性

| 组件 | 说明 | 端口 |
|------|------|------|
| **modemserver** | Go + Vue.js Web 管理界面 | 8080 |
| **quectel-CM-M** | Quectel 官方 QMI 拨号连接管理器 | — |
| **sendat** | AT 命令发送工具 | — |
| **tom_modem** | 模组诊断与管理工具 | — |

### 核心能力

- ✅ QMI WWAN 驱动自动绑定
- ✅ 开机自动 5G 拨号上网（IPv4）
- ✅ Web UI 管理模组（信号/运营商/流量等）
- ✅ USB 热插拔自动检测（插入启动，拔出停止）
- ✅ AT 命令交互（信号/运营商/小区/重启等）
- ✅ 进程守护（异常自动重启）

---

## 支持的模组

| 品牌 | 型号 | VID:PID | 备注 |
|------|------|---------|------|
| Quectel | RM520N-GL | 2c7c:0801 | ✅ 已测试 |
| Quectel | RM520N-GL | 2c7c:0900 | ⬜ 未测试 |
| Quectel | 其他 | 2c7c:030a | ⬜ 未测试 |

> 理论上所有使用 QMI 协议的 Quectel 5G/4G 模组均支持。

---

## 硬件要求

- **路由器**：ImmortalWrt 23.05.3 / OpenWRT 23.05+
- **架构**：ARM64 (aarch64_generic)
- **USB**：USB 3.0 端口（推荐）
- **模组**：Quectel 5G 模组（USB 模式）

---

## 目录结构

```
modem-5g/
├── Makefile                      # OpenWRT IPK 编译文件
├── README.md                     # 本文件
├── install.sh                   # 一键安装脚本
├── uninstall.sh                 # 卸载脚本
│
├── .github/
│   └── workflows/
│       └── build.yml            # GitHub Actions 自动编译
│
├── luasrc/                      # LuCI Web 界面
│   ├── controller/admin/
│   │   └── modemsrv.lua         # LuCI 控制器（注册菜单 + API 节点）
│   ├── model/network/
│   │   └── proto_modemmanager.lua # 网络协议扩展
│   └── view/modemsrv/
│       ├── 5Gmodem.htm         # 主页面（嵌入 modemserver）
│       └── 5Gmodeminfo.htm      # 状态页面（信号/流量实时监控）
│
├── root/etc/                    # 系统配置文件
│   ├── init.d/
│   │   ├── usbmode             # USB 模式初始化（START=20）
│   │   ├── modemserver         # Web UI 服务（START=99）
│   │   └── modemsrv_helper     # 自动拨号脚本（START=99）
│   ├── hotplug.d/usb/
│   │   └── 20-modem_mode       # USB 热插拔脚本
│   └── rc.d/
│       ├── S20usbmode          # 开机绑定 qmi_wwan 驱动
│       ├── S99modemserver       # 开机启动 Web UI
│       └── S99modemsrv         # 开机自动拨号
│
└── files/usr/bin/               # 二进制程序
    ├── modemserver             # Web 服务器（Go, 11.9MB）
    ├── quectel-CM-M            # 拨号工具（196KB）
    ├── sendat                  # AT 命令工具（64KB）
    └── tom_modem               # 模组管理工具（64KB）
```

---

## 自动启动逻辑

```
┌─────────────────────────────────────────────────────┐
│  第一层：系统启动（boot）                             │
│                                                       │
│  /etc/rc.d/S20usbmode  (START=20)                   │
│    → 检测 Quectel 模组 VID:PID                       │
│    → 确保 wwan0 设备存在且 UP                        │
│    → 为后续拨号准备网络接口                          │
│                                                       │
│  /etc/rc.d/S99modemsrv  (START=99)                  │
│    → 等待 wwan0 就绪                                │
│    → 启动 quectel-CM-M -s cmnet 自动拨号            │
│                                                       │
│  /etc/rc.d/S99modemserver (START=99)                 │
│    → 启动 modemserver（Web UI，端口 8080）            │
└───────────────────────────┬───────────────────────────┘
                            │  USB 插拔
                            ▼
┌─────────────────────────────────────────────────────┐
│  第二层：USB 热插拔（hotplug）                       │
│                                                       │
│  /etc/hotplug.d/usb/20-modem_mode                  │
│                                                       │
│  插入检测到 Quectel (2c7c:0801)                     │
│    → 等待 wwan0 就绪                                │
│    → 启动 quectel-CM-M 自动拨号                     │
│    → 启动 modemserver Web UI                        │
│                                                       │
│  拔出                                                 │
│    → 断开 quectel-CM-M 连接                         │
└─────────────────────────────────────────────────────┘
```

---

## 安装方式

### 方式一：GitHub 克隆（推荐）

```bash
# SSH 或 HTTPS 克隆
git clone https://github.com/a10463981/modem-5g.git /tmp/modem-5g
cd /tmp/modem-5g

# 运行安装脚本
chmod +x install.sh
./install.sh
```

### 方式二：下载 IPK（GitHub Actions 自动构建）

1. 访问 [Actions 页](https://github.com/a10463981/modem-5g/actions) 下载 Artifacts
2. 上传到路由器 `/tmp/`
3. 执行：
```bash
opkg install /tmp/modem-5g_*.ipk --force-overwrite
```

---

## 使用说明

### Web 管理界面

访问地址：**http://192.168.1.1:8080**

通过 LuCI 访问：**网络 → 5G Modem → 综合平台**

### AT 命令示例

```bash
# 查询信号强度
sendat /dev/ttyUSB2 AT+CSQ

# 查询运营商信息
sendat /dev/ttyUSB2 AT+COPS?

# 查询小区信息
sendat /dev/ttyUSB2 AT+CGNINFO

# 重启模组
sendat /dev/ttyUSB2 AT+CFUN=1,1
```

### 服务管理

```bash
# 查看服务状态
ps | grep -E "modemserver|quectel-CM"

# 查看网络接口
ip addr show wwan0

# 查看日志
logread | grep -E "usbmode|modem|hotplug" | tail -20

# 重启服务
/etc/init.d/modemserver restart
/etc/init.d/modemsrv_helper start
```

---

## 编译说明

### 环境要求

- ImmortalWrt SDK 23.05.3（Rockchip ARM64）
- 或 OpenWRT SDK 23.05+
- Linux 构建环境

### 本地编译

```bash
# 1. 下载 ImmortalWrt SDK
wget https://downloads.immortalwrt.org/releases/23.05.3/targets/rockchip/armv8/immortalwrt-sdk-23.05.3-rockchip-armv8_gcc-12.3.0_musl.Linux-x86_64.tar.xz
tar xf immortalwrt-sdk-*.tar.xz
cd immortalwrt-sdk-*

# 2. 链接本仓库
ln -s /path/to/modem-5g package/modem-5g

# 3. 安装 LuCI 依赖
./scripts/feeds update -a
./scripts/feeds install -a -p luci

# 4. 编译
echo 'CONFIG_PACKAGE_luci-app-modemserver=y' >> .config
make defconfig
make -j$(nproc) package/luci-app-modemserver/compile
```

---

## 卸载说明

```bash
# 自动卸载
chmod +x uninstall.sh
./uninstall.sh

# 或手动卸载
/etc/init.d/modemserver stop 2>/dev/null
/etc/init.d/modemsrv_helper stop 2>/dev/null
/etc/init.d/usbmode stop 2>/dev/null
killall quectel-CM-M 2>/dev/null

rm -f /usr/bin/modemserver /usr/bin/quectel-CM-M /usr/bin/sendat /usr/bin/tom_modem
rm -f /etc/init.d/modemserver /etc/init.d/usbmode /etc/init.d/modemsrv_helper
rm -f /etc/hotplug.d/usb/20-modem_mode
rm -f /usr/lib/lua/luci/controller/admin/modemsrv.lua
rm -rf /usr/lib/lua/luci/view/modemsrv
rm -f /etc/rc.d/S20usbmode /etc/rc.d/S99modemserver /etc/rc.d/S99modemsrv
```

---

## 常见问题

**Q: 模组已插入但 quectel-CM 没有自动连接？**
```bash
# 检查 USB 是否识别
lsusb | grep 2c7c

# 检查 wwan0 是否存在
ip link show wwan0

# 手动启动测试
/etc/init.d/modemsrv_helper start
```

**Q: modemserver Web 页面打不开？**
```bash
# 检查端口监听
netstat -tlnp | grep 8080

# 检查进程状态
ps | grep modemserver

# 查看启动日志
logread | grep modemserver | tail -10
```

**Q: 如何查看拨号是否成功？**
```bash
# 查看网络接口 IP
ip addr show wwan0

# 查看默认路由
ip route | grep wwan0

# 测试连通性
ping -I wwan0 8.8.8.8
```

---

## 更新日志

### v1.0.0 (2026-03-25)

- 初始版本发布
- 支持 Quectel RM520N-GL（2c7c:0801）
- modemserver Web UI（Go + Vue.js，端口 8080）
- quectel-CM-M 拨号管理（QMI IPv4）
- sendat / tom_modem AT 命令工具
- 完整 LuCI 管理界面集成
- USB 热插拔自动检测
- 三层启动机制（boot + hotplug + respawn）
- AYY 兄整理提供

---

## 致谢

- **原始开发者**：有房大佬 — 核心技术贡献者
- **整理提供**：AAYY兄 [www.aayy.top](http://www.aayy.top)

---

## 许可证

GPL-3.0

---

> ⚠️ **重要提示**：本插件仅供技术研究与测试使用，涉及的所有技术内容版权归原始开发者所有。如有任何侵权行为，请及时联系，将在第一时间删除处理。
