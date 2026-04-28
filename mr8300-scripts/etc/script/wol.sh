#!/bin/bash
# OpenWRT Wake-On-LAN Script

MAC_ADDRESS="90:B1:1C:6B:0F:35" # Replace with your PC's MAC address
INTERFACE="br-lan" # Replace with your network interface if different

# Send the WOL packet
etherwake -i $INTERFACE $MAC_ADDRESS -b
#etherwake -i br-lan 90:b1:1c:6b:0f:35
