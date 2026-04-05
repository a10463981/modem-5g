#!/bin/sh
echo "=========================================="
echo " 5G Modem 插件卸载 (modem-5g v1.1.6)"
echo "=========================================="
[ "$(id -u)" != "0" ] && { echo "错误: 请使用 root 权限运行"; exit 1; }

echo ""
echo "[1/4] 停止服务..."
/etc/init.d/modemserver stop 2>/dev/null && echo " modemserver 已停止"
/etc/init.d/modemsrv_helper stop 2>/dev/null && echo " modemsrv_helper 已停止"
/etc/init.d/usbmode stop 2>/dev/null && echo " usbmode 已停止"

echo ""
echo "[2/4] 禁用开机启动..."
/etc/init.d/modemserver disable 2>/dev/null
/etc/init.d/modemsrv_helper disable 2>/dev/null
/etc/init.d/usbmode disable 2>/dev/null
echo " 已禁用"

echo ""
echo "[3/4] 删除文件..."
rm -f /usr/bin/modemserver /usr/bin/quectel-CM-M /usr/bin/sendat /usr/bin/tom_modem
rm -f /etc/init.d/modemserver /etc/init.d/usbmode /etc/init.d/modemsrv_helper
rm -f /etc/hotplug.d/usb/20-modem_mode
rm -f /etc/config/modem /etc/ModemData.db /etc/usb-mode.json
rm -f /usr/lib/lua/luci/controller/admin/modemsrv.lua
rm -f /usr/lib/lua/luci/model/network/proto_modemmanager.lua
rm -rf /usr/lib/lua/luci/view/modemsrv
rm -f /etc/rc.d/S99modemserver /etc/rc.d/S98modemsrv /etc/rc.d/S20usbmode
echo " 已删除"

echo ""
echo "[4/4] 清理完成"
echo ""
echo "=========================================="
echo " 卸载完成"
echo "=========================================="
