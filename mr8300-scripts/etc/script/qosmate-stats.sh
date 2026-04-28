#!/bin/sh
# Show only CAKE Diffserv4 class headings

# Adjust interface as needed (eth1, ifb-eth1, lanX, etc.)
IFACE="pppoe-wan"

# Extract and print only the class names
tc -s qdisc show dev $IFACE | \
    awk '
    /^ *Bulk/        {printf "%-15s", "Bulk"}
    /^ *Best Effort/ {printf "%-15s", "Best Effort"}
    /^ *Video/       {printf "%-15s", "Video"}
    /^ *Voice/       {printf "%-15s", "Voice"}
    END {print ""}
    '
