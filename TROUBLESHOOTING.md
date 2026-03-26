# 5G模组管理插件（modem-5g）技术备忘录

**项目**：modem-5g | **日期**：2026-03-26
**目标**：在 iStoreOS（ImmortalWrt 23.05.3）上安装运行有房大佬的 5G 模组管理包

---

## 一、硬件环境

| 项目 | 值 |
|------|-----|
| 路由器 | iStoreOS（ImmortalWrt 23.05.3），Rockchip ARM64 |
| 5G模组 | Quectel RM520NGLAAR03A03M4（VID:PID = 2c7c:0801） |
| USB接口 | 2-1:1.4（QMI WWAN端点） |
| 设备节点 | /dev/cdc-wdm0、/dev/wwan0、/dev/ttyUSB2(AT) |
| APN | cmnet |
| 网络模式 | 5G_SA，中国移动 MCC:460 MNC:0 |

---

## 二、完整目录树（本地 modem-5g/）

```
modem-5g/
│
├── .gitattributes                          # 强制文本文件使用 LF 换行符
├── .github/
│   └── workflows/
│       └── build.yml                       # GitHub Actions 自动构建 IPK
│
├── files/                                 # 二进制程序（安装到 /usr/bin/）
│   └── usr/
│       └── bin/
│           ├── modemserver               # Web 服务器（Go，11.9MB，0755）
│           ├── quectel-CM-M              # QMI 拨号工具（196KB，0755）
│           ├── sendat                    # AT 命令工具（65KB，0755）
│           └── tom_modem                 # 模组诊断工具（66KB，0755）
│
├── kernel/                                # 驱动模块（安装到 /lib/modules/*/）
│   ├── cdc-acm.ko                       # USB ACM 驱动（33KB，0644）
│   ├── cdc_ether.ko                    # CDC Ethernet 驱动（15KB，0644）
│   ├── cdc_mbim.ko                     # CDC MBIM 驱动（13KB，0644）
│   ├── cdc_ncm.ko                      # CDC NCM 驱动（33KB，0644）
│   ├── huawei_cdc_ncm.ko              # 华为 CDC NCM（7KB，0644）
│   ├── modem-switch.ko                # 模组切换驱动（11KB，0644）
│   ├── qcserial.ko                    # Qualcomm 串口驱动（12KB，0644）
│   ├── qmi_helpers.ko                  # QMI 辅助驱动（22KB，0644）
│   ├── qmi_wwan.ko                    # QMI WWAN 主驱动（44KB，0644）
│   ├── qmi_wwan_f.ko                  # QMI WWAN F 变体（40KB，0644）
│   ├── qmi_wwan_q.ko                  # QMI WWAN Q 变体（41KB，0644）
│   ├── qmi_wwan_s.ko                  # QMI WWAN S 变体（11KB，0644）
│   ├── usb_wwan.ko                    # USB WWAN 驱动（15KB，0644）
│   ├── usbnet.ko                      # USB 网络驱动（45KB，0644）
│   └── usbserial.ko                   # USB 串口驱动（47KB，0644）
│
├── luasrc/                               # LuCI Web 界面（安装到 /usr/lib/lua/luci/）
│   ├── controller/
│   │   └── admin/
│   │       └── modemsrv.lua            # LuCI 控制器（0644）
│   ├── model/
│   │   └── network/
│   │       └── proto_modemmanager.lua  # 网络协议扩展（0644）
│   └── view/
│       └── modemsrv/
│           ├── 5Gmodem.htm              # 主页面模板（0644）
│           └── 5Gmodeminfo.htm         # 状态页面（0644）
│
├── root/                                 # 系统配置（安装到 /）
│   └── etc/
│       ├── config/
│       │   └── modem                   # LuCI 配置（0644）
│       ├── hotplug.d/
│       │   └── usb/
│       │       └── 20-modem_mode       # USB 热插拔脚本（0755）
│       ├── init.d/
│       │   ├── modemserver             # Web UI 服务（0755）
│       │   ├── modemsrv_helper        # 自动拨号脚本（0755）
│       │   └── usbmode                # USB 驱动初始化（0755）
│       └── rc.d/
│           ├── K10modemserver         # 关机停止脚本（0755）
│           ├── S20usbmode             # 开机驱动绑定（0755）
│           ├── S99modemserver         # 开机启动 Web UI（0755）
│           └── S99modemsrv            # 开机自动拨号（0755）
│
├── modem-5g-v1.0.0.zip               # 完整安装包（5.5MB）
├── Makefile                             # OpenWRT IPK 编译文件
├── README.md                            # 中文说明文档
├── README_EN.md                        # English documentation
├── install.sh                           # 一键安装脚本（0755）
└── uninstall.sh                        # 一键卸载脚本（0755）
```

---

## 三、文件对应路径详解（本地 → 路由器）

### 3.1 二进制程序

| 本地路径 | 路由器路径 | 权限 | 大小 | 说明 |
|----------|-----------|------|------|------|
| `files/usr/bin/modemserver` | `/usr/bin/modemserver` | 0755 rwxr-xr-x | 11.9MB | Go + Vue.js Web 服务器，端口 8080 |
| `files/usr/bin/quectel-CM-M` | `/usr/bin/quectel-CM-M` | 0755 rwxr-xr-x | 196KB | Quectel 官方 QMI 拨号，命令格式：`quectel-CM-M -s cmnet` |
| `files/usr/bin/sendat` | `/usr/bin/sendat` | 0755 rwxr-xr-x | 65KB | AT 命令发送工具，用法：`sendat /dev/ttyUSB2 AT+CSQ` |
| `files/usr/bin/tom_modem` | `/usr/bin/tom_modem` | 0755 rwxr-xr-x | 66KB | 模组诊断与管理工具 |

### 3.2 Init 启动脚本

| 本地路径 | 路由器路径 | 权限 | START/STOP | 说明 |
|----------|-----------|------|------------|------|
| `root/etc/init.d/usbmode` | `/etc/init.d/usbmode` | 0755 rwxr-xr-x | START=20 | 等待 USB 设备 /sys/bus/usb/devices/2-1就绪，检测 VID:PID=2c7c:0801，确保 wwan0 UP |
| `root/etc/init.d/modemserver` | `/etc/init.d/modemserver` | 0755 rwxr-xr-x | START=99, STOP=10 | 启动 `/usr/bin/modemserver -port 8080`，procd 守护，异常自动重启 |
| `root/etc/init.d/modemsrv_helper` | `/etc/init.d/modemsrv_helper` | 0755 rwxr-xr-x | START=99 | 等待 wwan0 就绪，执行 `quectel-CM-M -s cmnet &` 拨号 |

### 3.3 RC.D 启动链接

| 本地路径 | 路由器路径 | 权限 | 启动顺序 | 说明 |
|----------|-----------|------|----------|------|
| `root/etc/rc.d/S20usbmode` | `/etc/rc.d/S20usbmode` | 0755 rwxr-xr-x | START=20 | 开机第20顺位：确保 wwan0 设备 UP |
| `root/etc/rc.d/S99modemsrv` | `/etc/rc.d/S99modemsrv` | 0755 rwxr-xr-x | START=99 | 开机第99顺位：启动 quectel-CM-M 拨号 |
| `root/etc/rc.d/S99modemserver` | `/etc/rc.d/S99modemserver` | 0755 rwxr-xr-x | START=99 | 开机第99顺位：启动 modemserver Web UI |
| `root/etc/rc.d/K10modemserver` | `/etc/rc.d/K10modemserver` | 0755 rwxr-xr-x | STOP=10 | 关机第10顺位：停止 modemserver |

### 3.4 Hotplug 脚本

| 本地路径 | 路由器路径 | 权限 | 触发条件 | 说明 |
|----------|-----------|------|----------|------|
| `root/etc/hotplug.d/usb/20-modem_mode` | `/etc/hotplug.d/usb/20-modem_mode` | 0755 rwxr-xr-x | USB add/remove | USB 插拔时自动启停 quectel-CM-M，支持 VID:PID=2c7c:0801/0900/030a |

### 3.5 LuCI Web 界面

| 本地路径 | 路由器路径 | 权限 | 说明 |
|----------|-----------|------|------|
| `luasrc/controller/admin/modemsrv.lua` | `/usr/lib/lua/luci/controller/admin/modemsrv.lua` | 0644 rw-r--r-- | 模块名 `admin.modemsrv`，注册 entry `{"admin","modem"}`，API 节点 `{"admin","modem","qmodem","modem_ctrl"}` 和 `{"admin","modem","qmodem","get_modem_cfg"}` |
| `luasrc/model/network/proto_modemmanager.lua` | `/usr/lib/lua/luci/model/network/proto_modemmanager.lua` | 0644 rw-r--r-- | 注册 `modemmanager` 网络协议 |
| `luasrc/view/modemsrv/5Gmodem.htm` | `/usr/lib/lua/luci/view/modemsrv/5Gmodem.htm` | 0644 rw-r--r-- | 主页面模板，通过 iframe 嵌入 modemserver，传递 `<%=sysauth%>` 作为认证 key |
| `luasrc/view/modemsrv/5Gmodeminfo.htm` | `/usr/lib/lua/luci/view/modemsrv/5Gmodeminfo.htm` | 0644 rw-r--r-- | 状态页面，XHR 轮询 `admin/modem/qmodem/modem_ctrl`，实时显示信号/运营商/流量 |

### 3.6 配置文件

| 本地路径 | 路由器路径 | 权限 | 大小 | 说明 |
|----------|-----------|------|------|------|
| `root/etc/config/modem` | `/etc/config/modem` | 0644 rw-r--r-- | 149B | LuCI 界面配置数据 |
| `root/etc/usb-mode.json` | `/etc/usb-mode.json` | 0644 rw-r--r-- | 55KB | USB 模组模式切换配置 |
| `root/etc/ModemData.db` | `/etc/ModemData.db` | 0644 rw-r--r-- | 40KB | 模组数据缓存数据库 |

### 3.7 安装/卸载脚本

| 本地路径 | 执行方式 | 权限 | 说明 |
|----------|---------|------|------|
| `install.sh` | `sh install.sh` 或 `./install.sh` | 0755 rwxr-xr-x | 创建目录→复制文件→处理 ModemManager→启动服务，共7步 |
| `uninstall.sh` | `sh uninstall.sh` 或 `./uninstall.sh` | 0755 rwxr-xr-x | 停止服务→禁用→删除所有安装文件，共4步 |

### 3.8 驱动模块

| 本地路径 | 内核路径 | 权限 | 大小 | 说明 |
|----------|---------|------|------|------|
| `kernel/cdc-acm.ko` | `/lib/modules/*/cdc-acm.ko` | 0644 rw-r--r-- | 33KB | USB Abstract Control Model 驱动 |
| `kernel/cdc_ether.ko` | `/lib/modules/*/cdc_ether.ko` | 0644 rw-r--r-- | 15KB | CDC Ethernet 驱动 |
| `kernel/cdc_mbim.ko` | `/lib/modules/*/cdc_mbim.ko` | 0644 rw-r--r-- | 13KB | CDC MBIM 驱动 |
| `kernel/cdc_ncm.ko` | `/lib/modules/*/cdc_ncm.ko` | 0644 rw-r--r-- | 33KB | CDC NCM 驱动 |
| `kernel/huawei_cdc_ncm.ko` | `/lib/modules/*/huawei_cdc_ncm.ko` | 0644 rw-r--r-- | 7KB | 华为 CDC NCM 驱动 |
| `kernel/modem-switch.ko` | `/lib/modules/*/modem-switch.ko` | 0644 rw-r--r-- | 11KB | 模组模式切换驱动 |
| `kernel/qcserial.ko` | `/lib/modules/*/qcserial.ko` | 0644 rw-r--r-- | 12KB | Qualcomm 串口驱动 |
| `kernel/qmi_helpers.ko` | `/lib/modules/*/qmi_helpers.ko` | 0644 rw-r--r-- | 22KB | QMI 辅助驱动 |
| `kernel/qmi_wwan.ko` | `/lib/modules/*/qmi_wwan.ko` | 0644 rw-r--r-- | 44KB | **QMI WWAN 主驱动（核心）** |
| `kernel/qmi_wwan_f.ko` | `/lib/modules/*/qmi_wwan_f.ko` | 0644 rw-r--r-- | 40KB | QMI WWAN F 变体 |
| `kernel/qmi_wwan_q.ko` | `/lib/modules/*/qmi_wwan_q.ko` | 0644 rw-r--r-- | 41KB | QMI WWAN Q 变体 |
| `kernel/qmi_wwan_s.ko` | `/lib/modules/*/qmi_wwan_s.ko` | 0644 rw-r--r-- | 11KB | QMI WWAN S 变体 |
| `kernel/usb_wwan.ko` | `/lib/modules/*/usb_wwan.ko` | 0644 rw-r--r-- | 15KB | USB WWAN 驱动 |
| `kernel/usbnet.ko` | `/lib/modules/*/usbnet.ko` | 0644 rw-r--r-- | 45KB | USB 网络驱动（基础依赖） |
| `kernel/usbserial.ko` | `/lib/modules/*/usbserial.ko` | 0644 rw-r--r-- | 47KB | USB 串口驱动（基础依赖） |

---

## 四、权限速查表

| 路径类型 | 权限 | 符号 | 说明 |
|----------|------|------|------|
| /usr/bin/ （二进制） | 0755 | rwxr-xr-x | 可执行 |
| /etc/init.d/ （启动脚本） | 0755 | rwxr-xr-x | procd 可调用 |
| /etc/rc.d/ （rc 链接） | 0755 | rwxr-xr-x | 系统启动时执行 |
| /etc/hotplug.d/usb/ （热插拔） | 0755 | rwxr-xr-x | USB 事件触发 |
| /usr/lib/lua/luci/controller/ | 0644 | rw-r--r-- | 只读模块 |
| /usr/lib/lua/luci/model/ | 0644 | rw-r--r-- | 只读模块 |
| /usr/lib/lua/luci/view/ | 0644 | rw-r--r-- | 只读视图 |
| /etc/config/ （UCI 配置） | 0644 | rw-r--r-- | 可读写 |
| /etc/*.json / *.db | 0644 | rw-r--r-- | 只读数据 |
| install.sh / uninstall.sh | 0755 | rwxr-xr-x | 安装脚本 |
| kernel/*.ko | 0644 | rw-r--r-- | 驱动模块 |

---

## 五、遇到的问题及解决

### 问题1：开机后 wwan0 状态 DOWN，自动拨号失败

**现象**：kernel boot 时正确创建了 wwan0，但状态是 DOWN，logread 无 usbmode 日志

**根本原因**：`$(...)` 语法在 Ash shell 不支持，脚本静默失败

**正确方向**：全部改为反引号 `` `...` ``，不需要 unbind/rebind

---

### 问题2：quectel-CM-M 手动运行显示帮助信息

**现象**：直接运行 `quectel-CM-M` 不拨号，显示帮助

**根本原因**：缺少 APN 参数

**正确方向**：`quectel-CM-M -s cmnet`

---

### 问题3：quectel-CM-M 获得 IP 后立即断线

**现象**：DHCP 获取 IP 成功，但几秒后 DISCONNECTED

**正确方向**：quectel-CM-M 有自动重试机制，第二次/第三次尝试会成功

---

### 问题4：modemserver API 返回 401

**现象**：modemserver 认证失败，iframe 里 401

**根本原因**：`5Gmodem.htm` 里 cookie_header 变量定义了但没有 `<%=cookie_header%>` 输出

**正确方向**：改为 `<%=sysauth%>`

---

### 问题5：5Gmodeminfo.htm API 路径错误

**现象**：XHR 调用 `admin/modemserver/qmodem/modem_ctrl` 但 controller 注册的是 `admin/modem/qmodem/...`

**正确方向**：统一为 `{"admin", "modem", "qmodem", ...}`

---

### 问题6：install.sh CRLF 导致 Ash shell 报错

**现象**：`not found line 4: command not found`

**根本原因**：Windows CRLF 换行符被 Ash 当作命令

**正确方向**：添加 `.gitattributes` 强制 LF，脚本加 `sed -i 's/\r$//'`

---

### 问题7：ModemManager 与 quectel-CM 冲突

**正确方向**：`mv /etc/init.d/modemmanager /etc/init.d/modemmanager.bak`

---

### 问题8：qmi_wwan 绑定路径问题

**现象**：`*-1.4` glob 无法匹配 `2-1:1.4`

**正确方向**：VID/PID 在父目录 `/sys/bus/usb/devices/2-1/`，不是接口目录

---

## 六、三层启动逻辑

```
第一层：系统启动 boot
━━━━━━━━━━━━━━━━━━
S20usbmode (START=20)
  → 等待 /sys/bus/usb/devices/2-1
  → 检测 VID:PID = 2c7c:0801
  → 等待 wwan0 出现
  → ip link set wwan0 up

S99modemsrv (START=99)
  → 等待 wwan0
  → quectel-CM-M -s cmnet &

S99modemserver (START=99)
  → /usr/bin/modemserver -port 8080

第二层：USB 热插拔
━━━━━━━━━━━━━━━━━━
/etc/hotplug.d/usb/20-modem_mode
  → ACTION=add：启动 quectel-CM-M
  → ACTION=remove：停止 quectel-CM-M

第三层：进程守护 procd
━━━━━━━━━━━━━━━━━━
异常退出 → 自动 respawn
```

---

## 七、关键命令

```bash
# 查看模组 USB
lsusb | grep 2c7c

# 查看 wwan0 状态
ip link show wwan0

# 手动拨号
quectel-CM-M -s cmnet &

# 查看服务进程
ps | grep -E "modemserver|quectel-CM"

# 查看日志
logread | grep -E "usbmode|modem|hotplug"

# 重启服务
/etc/init.d/modemserver restart
/etc/init.d/modemsrv_helper start

# AT 命令
sendat /dev/ttyUSB2 AT+CSQ
sendat /dev/ttyUSB2 AT+COPS?
sendat /dev/ttyUSB2 AT+CGNINFO
```

---

## 八、GitHub 信息

| 项目 | 值 |
|------|-----|
| 仓库 | https://github.com/a10463981/modem-5g |
| 包名 | luci-app-modemserver（不变） |
| 安装包 | modem-5g-v1.0.0.zip（5.5MB） |
| 文档 | README.md（中文）+ README_EN.md（英文） |

---

*最后更新：2026-03-26*
