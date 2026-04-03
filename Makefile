include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-modemserver
PKG_VERSION:=1.0.0
PKG_RELEASE:=4
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
 【安装必读】
 本包文件 /etc/init.d/usbmode 和 /etc/usb-mode.json 与系统自带
 的 usb-modeswitch 包冲突（内容不同，本包为 Quectel 5G 定制版）。
 安装时必须加 --force-overwrite 参数，否则 opkg 会报文件冲突错误。

 正确安装命令：
   opkg install /tmp/upload.ipk --force-overwrite

 卸载命令：
   opkg remove luci-app-modemserver
 ============================================================
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cp -r $(CURDIR)/luasrc $(PKG_BUILD_DIR)/
	cp -r $(CURDIR)/root $(PKG_BUILD_DIR)/
	cp -r $(CURDIR)/files $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
	@:
endef

define Package/luci-app-modemserver/install
	# LuCI controller / view (no model/ - luasrc/model/ does not exist in this repo)
	mkdir -p $(1)/usr/lib/lua/luci/controller
	mkdir -p $(1)/usr/lib/lua/luci/view
	cp -r $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller/
	cp -r $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view/
	# init.d - all three scripts (modemserver, modemsrv_helper, usbmode)
	mkdir -p $(1)/etc/init.d
	cp $(PKG_BUILD_DIR)/root/etc/init.d/modemserver $(1)/etc/init.d/
	cp $(PKG_BUILD_DIR)/root/etc/init.d/modemsrv_helper $(1)/etc/init.d/
	cp $(PKG_BUILD_DIR)/root/etc/init.d/usbmode $(1)/etc/init.d/        # Quectel 5G 定制版，覆盖系统的 usb-modeswitch
	chmod 0755 $(1)/etc/init.d/modemserver
	chmod 0755 $(1)/etc/init.d/modemsrv_helper
	chmod 0755 $(1)/etc/init.d/usbmode
	# usb-mode.json - Quectel 5G 配置，覆盖系统 usb-modeswitch 的同名文件
	mkdir -p $(1)/etc
	cp $(PKG_BUILD_DIR)/root/etc/usb-mode.json $(1)/etc/usb-mode.json
	# config / hotplug.d
	mkdir -p $(1)/etc/config
	mkdir -p $(1)/etc/hotplug.d/usb
	cp $(PKG_BUILD_DIR)/root/etc/config/modem $(1)/etc/config/
	cp $(PKG_BUILD_DIR)/root/etc/hotplug.d/usb/20-modem_mode $(1)/etc/hotplug.d/usb/
	chmod 0755 $(1)/etc/hotplug.d/usb/20-modem_mode
	# rc.d - symlinks to init.d (OpenWrt 规范：rc.d/ 只含 symlink，不含脚本本身)
	mkdir -p $(1)/etc/rc.d
	ln -s ../init.d/modemserver $(1)/etc/rc.d/S99modemserver
	ln -s ../init.d/modemsrv_helper $(1)/etc/rc.d/S99modemsrv
	ln -s ../init.d/usbmode $(1)/etc/rc.d/S20usbmode
	# bin scripts
	mkdir -p $(1)/usr/bin
	cp $(PKG_BUILD_DIR)/files/usr/bin/modemserver $(1)/usr/bin/
	cp $(PKG_BUILD_DIR)/files/usr/bin/quectel-CM-M $(1)/usr/bin/
	cp $(PKG_BUILD_DIR)/files/usr/bin/sendat $(1)/usr/bin/
	cp $(PKG_BUILD_DIR)/files/usr/bin/tom_modem $(1)/usr/bin/
	chmod 0755 $(1)/usr/bin/modemserver
	chmod 0755 $(1)/usr/bin/quectel-CM-M
	chmod 0755 $(1)/usr/bin/sendat
	chmod 0755 $(1)/usr/bin/tom_modem
endef

define Package/luci-app-modemserver/postinst
#!/bin/sh
chmod +x /etc/init.d/modemserver /etc/init.d/modemsrv_helper /etc/init.d/usbmode
/etc/init.d/modemsrv_helper enable 2>/dev/null
/etc/init.d/modemserver enable 2>/dev/null
/etc/init.d/usbmode enable 2>/dev/null
/etc/init.d/modemsrv_helper start 2>/dev/null
/etc/init.d/modemserver start 2>/dev/null
exit 0
endef

$(eval $(call BuildPackage,luci-app-modemserver))
