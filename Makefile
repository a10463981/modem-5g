include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-modemserver
PKG_VERSION:=1.0.0
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
  URL:=https://github.com/a10463981/modem-5g
endef

define Package/luci-app-modemserver/description
 5G模组管理界面 (Web UI 端口8080)
 有房大佬出品 | 包含: modemserver, quectel-CM-M, sendat, tom_modem
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
	# LuCI controller / model / view - create dirs first
	mkdir -p $(1)/usr/lib/lua/luci/controller
	mkdir -p $(1)/usr/lib/lua/luci/model
	mkdir -p $(1)/usr/lib/lua/luci/view
	cp -r $(PKG_BUILD_DIR)/luasrc/controller/* $(1)/usr/lib/lua/luci/controller/
	cp -r $(PKG_BUILD_DIR)/luasrc/model/* $(1)/usr/lib/lua/luci/model/
	cp -r $(PKG_BUILD_DIR)/luasrc/view/* $(1)/usr/lib/lua/luci/view/
	# init.d / hotplug / config
	cp -r $(PKG_BUILD_DIR)/root/etc $(1)/
	# bin scripts
	cp -r $(PKG_BUILD_DIR)/files/usr $(1)/
	# set executable permissions
	chmod 0755 $(1)/usr/bin/modemserver
	chmod 0755 $(1)/usr/bin/quectel-CM-M
	chmod 0755 $(1)/usr/bin/sendat
	chmod 0755 $(1)/usr/bin/tom_modem
	chmod 0755 $(1)/etc/init.d/modemserver
	chmod 0755 $(1)/etc/init.d/usbmode
	chmod 0755 $(1)/etc/init.d/modemsrv_helper
	chmod 0755 $(1)/etc/hotplug.d/usb/20-modem_mode
endef

define Package/luci-app-modemserver/postinst
#!/bin/sh
chmod +x /etc/init.d/modemserver /etc/init.d/usbmode /etc/init.d/modemsrv_helper
chmod +x /etc/hotplug.d/usb/20-modem_mode
/etc/init.d/usbmode enable 2>/dev/null
/etc/init.d/modemsrv_helper enable 2>/dev/null
/etc/init.d/modemserver enable 2>/dev/null
/etc/init.d/usbmode start 2>/dev/null
/etc/init.d/modemsrv_helper start 2>/dev/null
/etc/init.d/modemserver start 2>/dev/null
exit 0
endef

$(eval $(call BuildPackage,luci-app-modemserver))
