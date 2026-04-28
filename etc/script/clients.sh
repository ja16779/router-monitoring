#!/bin/sh
echo "IP Address    Hostname    MAC Address"
for interface in $(iw dev | grep Interface | cut -d" " -f2); do
    for mac in $(iw dev $interface station dump | grep Station | cut -d" " -f2); do
        ip=$(grep $mac /tmp/dhcp.leases | cut -d" " -f3)
        host=$(grep $mac /tmp/dhcp.leases | cut -d" " -f4)
        echo "$ip    $host    $mac"
    done
done
