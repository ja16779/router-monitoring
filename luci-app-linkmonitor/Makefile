include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-linkmonitor
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=LinkMonitor <linkmonitor@openwrt.local>

LUCI_TITLE:=LuCI Link Monitor
LUCI_DESCRIPTION:=Network link monitoring with configurable alerts. \
 Monitor hosts via ping, HTTP and DNS checks. Get alerts via syslog, \
 email, custom scripts or webhooks when links go down or recover.
LUCI_DEPENDS:=+luci-base +curl
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/conffiles
/etc/config/linkmonitor
endef

# call BuildPackage - OpenWrt buildance Infra
$(eval $(call BuildPackage,$(PKG_NAME)))
