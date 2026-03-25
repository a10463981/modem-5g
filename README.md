# modem-5g

**5G 模组管理插件** — 有房大佬出品 | 支持 Quectel RM520N-GL 及全系列 Quectel 5G 模组

## 功能特性

| 组件 | 说明 | 端口 |
|------|------|------|
| **modemserver** | Go 编写的 Web 管理界面 | 8080 |
| **quectel-CM-M** | Quectel 拨号连接管理器 | - |
| **sendat** | AT 命令发送工具 | - |
| **tom_modem** | 模组管理工具 | - |

## 支持的平台

- **架构**: ARM64 (aarch64_generic)
- **内核**: 5.15.x / 6.6.x
- **系统**: ImmortalWrt 23.05.3 / OpenWRT 23.05

## 安装方式

### 方式一：直接安装 IPK（推荐）

下载编译好的 ipk 文件，上传到路由器后执行：

```bash
opkg install modem-5g_1.0.0-1_aarch64_generic.ipk --force-overwrite
```

### 方式二：手动安装

```bash
git clone https://github.com/a10463981/modem-5g.git /tmp/modem-5g
cd /tmp/modem-5g
chmod +x install.sh
./install.sh
```

## 自动启动机制

| 阶段 | 行为 |
|------|------|
| **系统启动** | modemserver Web UI 自动启动（端口 8080） |
| **USB 模组插入** | hotplug 自动检测并启动 quectel-CM 拨号 + modemserver |
| **服务异常退出** | procd 自动重启（respawn） |

## Web 管理界面

访问地址：`http://192.168.1.1:8080`

## 致谢

**有房大佬** - 核心技术贡献者

## 许可证

GPL-3.0
