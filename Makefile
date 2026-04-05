include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-modemserver
PKG_VERSION:=1.1.6
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0
PKG_MAINTAINER:=有房大佬

# Pure LuCI app + shell scripts, no compilation
PKG_BUILD_DEPENDS:=lua/host
PKG_USE_MKFILE:=0

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-modemserver
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=5G Modem
  TITLE:=5G Modem Server Management Interface
  DEPENDS:=+luci-compat +kmod-usb-core +kmod-usb-net +kmod-usb-serial-option +kmod-usb-acm +kmod-usb-wdm +kmod-usb-net-cdc-ether +kmod-usb-net-cdc-mbim +kmod-usb-net-cdc-ncm +kmod-usb-net-qmi-wwan
  CONFLICTS:=usb-modeswitch
  REPLACES:=usb-modeswitch
  URL:=https://github.com/a10463981/modem-5g
endef

define Package/luci-app-modemserver/description
 5G模组管理界面 (Web UI 端口8080)
 有房大佬出品 | 包含: modemserver, quectel-CM-M, sendat, tom_modem

 ============================================================
 【安装必读 — 必须执行以下两步】
 第一步（必选）：先卸载冲突的 usb-modeswitch
   opkg remove usb-modeswitch --force-depends

 第二步（必选）：安装本插件，必须加 --force-overwrite
   opkg install /tmp/upload.ipk --force-overwrite

 完整安装命令（两行都要执行）：
   opkg remove usb-modeswitch --force-depends
   opkg install /tmp/upload.ipk --force-overwrite

 原因：本包文件 /etc/init.d/usbmode 和 /etc/usb-mode.json 与系统自带
 的 usb-modeswitch 包冲突（内容不同，本包为 Quectel 5G 定制版）。

 卸载命令：
   opkg remove luci-app-modemserver
 ============================================================
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/files $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
	@:
endef

define Package/luci-app-modemserver/install
	# LuCI controller / view
	mkdir -p $(1)/usr/lib/lua/luci/controller
	mkdir -p $(1)/usr/lib/lua/luci/view
	$(CP) $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller/
	$(CP) $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view/
	# init.d - all three scripts (modemserver, modemsrv_helper, usbmode)
	mkdir -p $(1)/etc/init.d
	$(CP) $(PKG_BUILD_DIR)/root/etc/init.d/modemserver $(1)/etc/init.d/
	$(CP) $(PKG_BUILD_DIR)/root/etc/init.d/modemsrv_helper $(1)/etc/init.d/
	$(CP) $(PKG_BUILD_DIR)/root/etc/init.d/usbmode $(1)/etc/init.d/
	chmod 0755 $(1)/etc/init.d/modemserver
	chmod 0755 $(1)/etc/init.d/modemsrv_helper
	chmod 0755 $(1)/etc/init.d/usbmode
	# usb-mode.json - Quectel 5G 配置，覆盖系统 usb-modeswitch 的同名文件
	mkdir -p $(1)/etc
	$(CP) $(PKG_BUILD_DIR)/root/etc/usb-mode.json $(1)/etc/usb-mode.json
	# ModemData.db - 模组数据缓存
	$(CP) $(PKG_BUILD_DIR)/root/etc/ModemData.db $(1)/etc/ModemData.db
	# config / hotplug.d
	mkdir -p $(1)/etc/config
	mkdir -p $(1)/etc/hotplug.d/usb
	$(CP) $(PKG_BUILD_DIR)/root/etc/config/modem $(1)/etc/config/
	$(CP) $(PKG_BUILD_DIR)/root/etc/hotplug.d/usb/20-modem_mode $(1)/etc/hotplug.d/usb/
	chmod 0755 $(1)/etc/hotplug.d/usb/20-modem_mode
	# rc.d - symlinks to init.d (OpenWrt 规范：rc.d/ 只含 symlink，不含脚本本身)
	mkdir -p $(1)/etc/rc.d
	ln -s ../init.d/modemserver $(1)/etc/rc.d/S99modemserver
	ln -s ../init.d/modemsrv_helper $(1)/etc/rc.d/S98modemsrv
	ln -s ../init.d/usbmode $(1)/etc/rc.d/S20usbmode
	# bin scripts
	mkdir -p $(1)/usr/bin
	$(CP) $(PKG_BUILD_DIR)/files/usr/bin/modemserver $(1)/usr/bin/
	$(CP) $(PKG_BUILD_DIR)/files/usr/bin/quectel-CM-M $(1)/usr/bin/
	$(CP) $(PKG_BUILD_DIR)/files/usr/bin/sendat $(1)/usr/bin/
	$(CP) $(PKG_BUILD_DIR)/files/usr/bin/tom_modem $(1)/usr/bin/
	chmod 0755 $(1)/usr/bin/modemserver
	chmod 0755 $(1)/usr/bin/quectel-CM-M
	chmod 0755 $(1)/usr/bin/sendat
	chmod 0755 $(1)/usr/bin/tom_modem
endef

define Package/luci-app-modemserver/postinst
#!/bin/sh
set -e

chmod +x /etc/init.d/modemserver /etc/init.d/modemsrv_helper /etc/init.d/usbmode

/etc/init.d/modemsrv_helper enable
/etc/init.d/modemserver enable
/etc/init.d/usbmode enable

# 顺序启动：先等 usbmode 完成驱动绑定，再启动 modemserver
/etc/init.d/usbmode start
/etc/init.d/modemsrv_helper start
/etc/init.d/modemserver start

# 验证 modemserver 是否正常监听 8080
echo "等待 modemserver 启动..."
for i in $(seq 1 10); do
    if curl -s http://127.0.0.1:8080 >/dev/null 2>&1; then
        echo "modemserver 已启动 (http://127.0.0.1:8080)"
        exit 0
    fi
    sleep 1
done

# 启动失败，打印日志
echo "[ERROR] modemserver 启动失败，请运行以下命令排查："
echo "  logread | grep modemserver"
echo "  ps | grep modemserver"
echo "  /usr/bin/modemserver -port 8080 &  # 前台运行看报错"
exit 1
endef

$(eval $(call BuildPackage,luci-app-modemserver))
