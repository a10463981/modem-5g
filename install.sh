#!/bin/sh
#===============================================
# modem-5g 安装脚本
# 有房大佬出品
# 适用: ImmortalWrt 23.05.3 / OpenWRT 23.05
# 架构: aarch64_generic (ARM64)
#===============================================

set -e

BACKUP_DIR="/tmp/modem-backup-$(date +%Y%m%d%H%M%S)"

echo "=========================================="
echo " 5G Modem 插件安装脚本"
echo " 有房大佬出品"
echo "=========================================="

if [ "$(id -u)" != "0" ]; then
    echo "错误: 请使用 root 权限运行"
    exit 1
fi

SCRIPT_DIR="$(dirname "$0")"

# 备份
echo ""
echo "[1/6] 备份现有文件..."
mkdir -p "${BACKUP_DIR}"
[ -f /usr/bin/modemserver ] && cp /usr/bin/modemserver "${BACKUP_DIR}/"
[ -f /usr/bin/quectel-CM-M ] && cp /usr/bin/quectel-CM-M "${BACKUP_DIR}/"
[ -f /usr/bin/sendat ] && cp /usr/bin/sendat "${BACKUP_DIR}/"
[ -f /usr/bin/tom_modem ] && cp /usr/bin/tom_modem "${BACKUP_DIR}/"
[ -f /etc/init.d/modemserver ] && cp /etc/init.d/modemserver "${BACKUP_DIR}/"
[ -f /etc/init.d/usbmode ] && cp /etc/init.d/usbmode "${BACKUP_DIR}/"
[ -f /etc/init.d/quectel-CM ] && cp /etc/init.d/quectel-CM "${BACKUP_DIR}/"
[ -f /etc/hotplug.d/usb/20-modem_mode ] && cp /etc/hotplug.d/usb/20-modem_mode "${BACKUP_DIR}/"
echo " 备份已保存到: ${BACKUP_DIR}"

# 创建目录
echo ""
echo "[2/6] 创建目录结构..."
mkdir -p /usr/bin /etc/init.d /etc/hotplug.d/usb /etc/rc.d /etc/config
mkdir -p /usr/lib/lua/luci/controller /usr/lib/lua/luci/model/network /usr/lib/lua/luci/view/modemsrv
echo " 完成"

# 安装二进制
echo ""
echo "[3/6] 安装二进制文件..."
for f in modemserver quectel-CM-M sendat tom_modem; do
    [ -f "${SCRIPT_DIR}/files/usr/bin/$f" ] && {
        cp "${SCRIPT_DIR}/files/usr/bin/$f" /usr/bin/
        chmod +x /usr/bin/$f
        echo " 安装: $f"
    }
done

# 安装启动脚本
echo ""
echo "[4/6] 安装启动脚本..."
for f in modemserver usbmode quectel-CM; do
    [ -f "${SCRIPT_DIR}/root/etc/init.d/$f" ] && {
        cp "${SCRIPT_DIR}/root/etc/init.d/$f" /etc/init.d/
        chmod +x /etc/init.d/$f
        echo " 安装: /etc/init.d/$f"
    }
done

# 安装 hotplug
[ -f "${SCRIPT_DIR}/root/etc/hotplug.d/usb/20-modem_mode" ] && {
    cp "${SCRIPT_DIR}/root/etc/hotplug.d/usb/20-modem_mode" /etc/hotplug.d/usb/
    chmod +x /etc/hotplug.d/usb/20-modem_mode
    echo " 安装: /etc/hotplug.d/usb/20-modem_mode"
}

# 安装 LuCI
echo ""
echo "[5/6] 安装 LuCI 界面..."
[ -d "${SCRIPT_DIR}/luasrc/controller/admin" ] && cp "${SCRIPT_DIR}"/luasrc/controller/admin/*.lua /usr/lib/lua/luci/controller/
[ -d "${SCRIPT_DIR}/luasrc/model/network" ] && cp "${SCRIPT_DIR}"/luasrc/model/network/*.lua /usr/lib/lua/luci/model/network/
[ -d "${SCRIPT_DIR}/luasrc/view/modemsrv" ] && cp "${SCRIPT_DIR}"/luasrc/view/modemsrv/*.htm /usr/lib/lua/luci/view/modemsrv/
echo " LuCI 界面已安装"

# 安装配置
[ -f "${SCRIPT_DIR}/root/etc/config/modem" ] && cp "${SCRIPT_DIR}/root/etc/config/modem" /etc/config/modem
[ -f "${SCRIPT_DIR}/root/etc/ModemData.db" ] && cp "${SCRIPT_DIR}/root/etc/ModemData.db" /etc/
[ -f "${SCRIPT_DIR}/root/etc/usb-mode.json" ] && cp "${SCRIPT_DIR}/root/etc/usb-mode.json" /etc/

# 启用并启动
echo ""
echo "[6/6] 启用并启动服务..."
/etc/init.d/modemserver enable 2>/dev/null
/etc/init.d/usbmode enable 2>/dev/null
/etc/init.d/quectel-CM enable 2>/dev/null
/etc/init.d/modemserver start 2>/dev/null
echo " 服务已启动"

# 验证
echo ""
echo "=========================================="
echo " 安装验证"
echo "=========================================="
echo -n " modemserver: "
ps | grep -q "[m]odemserver" && echo "运行中" || echo "未运行"
echo -n " quectel-CM: "
ps | grep -q "[q]uectel-CM" && echo "运行中" || echo "未运行"
echo -n " 端口 8080: "
netstat -tlnp 2>/dev/null | grep -q ":8080" && echo "监听中" || echo "未监听"
echo ""
echo " Web 管理界面: http://$(uci get network.lan.ipaddr 2>/dev/null || echo '192.168.1.1'):8080"
echo "=========================================="
echo " 安装完成！"
echo "=========================================="
