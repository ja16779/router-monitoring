#!/bin/sh
/etc/init.d/cake stop; rm /root/cake.sh; rm /etc/init.d/cake; rm /etc/hotplug.d/iface/99-cake; rm /etc/nftables.d/*-rules.nft; sed -i "/default_qdisc/d; /tcp_congestion_control/d; /tcp_ecn/d" /etc/sysctl.conf; uci set dhcp.odhcpd.loglevel="4"; uci set irqbalance.irqbalance.enabled="0"; uci del network.globals.packet_steering; uci commit && reload_config
