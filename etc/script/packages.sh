#!/bin/sh
rm /tmp/packages*.txt
OPENWRT_VERSION=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d'=' -f2 | tr -d "'")
FLASH_TIME="$(awk '
$1 == "Installed-Time:" && ($2 < OLDEST || OLDEST=="") {
  OLDEST=$2
}
END {
  print OLDEST
}
' /usr/lib/opkg/status)"

awk -v FT="$FLASH_TIME" '
$1 == "Package:" {
  PKG=$2
  USR=""
}
$1 == "Status:" && $3 ~ "user" {
  USR=1
}
$1 == "Installed-Time:" && USR && $2 != FT {
  print PKG
}
' /usr/lib/opkg/status | sort >> /tmp/packages-${HOSTNAME}-${OPENWRT_VERSION}-$(date +%F).txt

rm /etc/config/my_installed_packages
#opkg list-installed > /etc/config/my_installed_packages
cp /tmp/packages-${HOSTNAME}-${OPENWRT_VERSION}-$(date +%F).txt /etc/config/my_installed_packages
cp /etc/config/my_installed_packages /tmp/mountd/disk2_part1/my_installed_packages-${OPENWRT_VERSION}-$(date +%F).txt


#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
MENSAJE="Paquetes Instalados"
ARCHIVO="/tmp/packages-${HOSTNAME}-${OPENWRT_VERSION}-$(date +%F).txt"
URL1="https://api.telegram.org/bot$TOKEN/sendDocument"
curl -X  POST $URL1 -F chat_id=$ID -F document="@/tmp/mountd/disk2_part1/my_installed_packages-${OPENWRT_VERSION}-$(date +%F).txt" > /dev/null
