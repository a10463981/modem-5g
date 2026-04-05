#!/bin/sh
# 一键安装脚本 — v1.1.6 修复版
# 适用于 iStoreOS / ImmortalWrt / OpenWRT

set -e

echo "============================================"
echo "  5G模组管理包 (modem-5g) v1.1.6 安装程序"
echo "============================================"

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "错误：请使用 root 权限运行 (sudo sh install.sh)"
    exit 1
fi

# 检查 platform
if ! grep -q "immortalwrt\|openwrt\|istoreos" /etc/openwrt_release 2>/dev/null; then
    echo "警告：未检测到 OpenWRT/ImmortalWrt 系统，尝试继续安装..."
fi

echo ""
echo "[1/7] 创建目录结构..."
mkdir -p /usr/bin
mkdir -p /usr/lib/lua/luci/controller/admin
mkdir -p /usr/lib/lua/luci/view/modemsrv
mkdir -p /etc/init.d
mkdir -p /etc/hotplug.d/usb
mkdir -p /etc/rc.d
mkdir -p /etc/config
mkdir -p /etc/hotplug.d/usb

echo "[2/7] 安装二进制文件..."
cp files/usr/bin/modemserver /usr/bin/modemserver
cp files/usr/bin/quectel-CM-M /usr/bin/quectel-CM-M
cp files/usr/bin/sendat /usr/bin/sendat
cp files/usr/bin/tom_modem /usr/bin/tom_modem
chmod 755 /usr/bin/modemserver /usr/bin/quectel-CM-M /usr/bin/sendat /usr/bin/tom_modem
echo "    完成 (4个二进制文件)"

echo "[3/7] 安装 LuCI Web 界面..."
cp luasrc/controller/admin/modemsrv.lua /usr/lib/lua/luci/controller/admin/modemsrv.lua
cp luasrc/view/modemsrv/*.htm /usr/lib/lua/luci/view/modemsrv/
chmod 644 /usr/lib/lua/luci/controller/admin/modemsrv.lua
chmod 644 /usr/lib/lua/luci/view/modemsrv/*.htm
echo "    完成 (LuCI控制器 + 视图文件)"

echo "[4/7] 安装系统启动脚本..."
cp root/etc/init.d/usbmode /etc/init.d/usbmode
cp root/etc/init.d/modemserver /etc/init.d/modemserver
cp root/etc/init.d/modemsrv_helper /etc/init.d/modemsrv_helper
chmod 755 /etc/init.d/usbmode /etc/init.d/modemserver /etc/init.d/modemsrv_helper

# 安装 rc.d 启动链接（OpenWrt 标准：rc.d/ 只含 symlink）
ln -sf ../init.d/modemserver /etc/rc.d/S99modemserver
ln -sf ../init.d/modemsrv_helper /etc/rc.d/S98modemsrv
ln -sf ../init.d/usbmode /etc/rc.d/S20usbmode
chmod 755 /etc/rc.d/S99modemserver /etc/rc.d/S98modemsrv /etc/rc.d/S20usbmode

# 安装 hotplug 脚本
cp root/etc/hotplug.d/usb/20-modem_mode /etc/hotplug.d/usb/20-modem_mode
chmod 755 /etc/hotplug.d/usb/20-modem_mode

echo "    完成 (init脚本 + rc.d链接 + hotplug)"

echo "[5/7] 安装配置文件..."
[ -f root/etc/config/modem ] && cp root/etc/config/modem /etc/config/modem
chmod 644 /etc/config/modem 2>/dev/null || true
[ -f root/etc/ModemData.db ] && cp root/etc/ModemData.db /etc/ModemData.db
chmod 644 /etc/ModemData.db 2>/dev/null || true

echo "[6/7] 处理 ModemManager 冲突..."
if [ -f /etc/init.d/modemmanager ]; then
    echo "    检测到 ModemManager，正在处理冲突..."
    /etc/init.d/modemmanager stop 2>/dev/null
    killall ModemManager 2>/dev/null
    mv /etc/init.d/modemmanager /etc/init.d/modemmanager.bak
    echo "    已将 ModemManager 重命名为 modemmanager.bak（禁用）"
else
    echo "    ModemManager 未安装，跳过"
fi

echo "[7/7] 启动服务..."
/etc/init.d/usbmode start 2>/dev/null && echo "    usbmode 已启动"
/etc/init.d/modemsrv_helper start 2>/dev/null && echo "    自动拨号已启动"
/etc/init.d/modemserver start 2>/dev/null && echo "    modemserver (Web UI) 已启动"

echo ""
echo "============================================"
echo "  安装完成!"
echo "============================================"
echo ""
echo "请访问: http://<路由器IP>:8080"
echo ""
echo "如需查看日志:"
echo "  logread | grep -E 'usbmode|modem|hotplug'"
echo ""
echo "如需手动重启服务:"
echo "  /etc/init.d/modemserver restart   # Web UI"
echo "  /etc/init.d/modemsrv_helper start  # 自动拨号"
echo ""
