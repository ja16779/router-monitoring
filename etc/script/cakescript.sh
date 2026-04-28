#!bin/sh
opkg update && opkg install tc-tiny kmod-sched-cake kmod-veth kmod-tcp-bbr irqbalance kmod-sched-ctinfo kmod-ifb
rm /root/cake.sh; rm /etc/init.d/cake; rm /etc/hotplug.d/iface/99-cake; rm /etc/nftables.d/*-rules.nft; wget -O /root/cake.sh "https://raw.githubusercontent.com/hudra0/CAKE-QoS-Script-OpenWrt/main/cake.sh"; chmod 755 /root/cake.sh
