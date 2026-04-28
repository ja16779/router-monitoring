#!/bin/sh

opkg update
wget --no-check-certificate -O /tmp/internet-detector_1.4.6-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/internet-detector_1.4.6-r1_all.ipk
opkg install /tmp/internet-detector_1.4.6-r1_all.ipk
#rm /tmp/internet-detector_1.4.6-r1_all.ipk
service internet-detector start
service internet-detector enable

wget --no-check-certificate -O /tmp/luci-app-internet-detector_1.4.6-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-app-internet-detector_1.4.6-r1_all.ipk
opkg install /tmp/luci-app-internet-detector_1.4.6-r1_all.ipk
#rm /tmp/luci-app-internet-detector_1.4.6-r1_all.ipk
service rpcd restart

wget --no-check-certificate -O /tmp/internet-detector-mod-telegram_1.6.5-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/internet-detector-mod-telegram_1.6.5-r1_all.ipk
opkg install /tmp/internet-detector-mod-telegram_1.6.5-r1_all.ipk
#rm /tmp/internet-detector-mod-telegram_1.6.5-r1_all.ipk
service internet-detector restart
