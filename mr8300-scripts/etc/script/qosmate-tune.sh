#!/bin/sh
# CAKE tuning script for pppoe-wan (egress) and ifb-pppoe-wan (ingress)

# Use ~95–96% of real line rate
UPLINK="350Mbit"
DOWNLINK="350Mbit"

# PPPoE overhead over GPON
OVERHEAD="34"
MPU="64"

### === Ingress shaping (DOWNLOAD) ===
tc qdisc replace dev ifb-pppoe-wan root cake \
    bandwidth $DOWNLINK \
    diffserv4 \
    dual-dsthost \
    nonat wash \
    ingress \
    ack-filter \
    split-gso \
    rtt 30ms \
    noatm \
    overhead $OVERHEAD \
    mpu $MPU

### === Egress shaping (UPLOAD) ===
tc qdisc replace dev pppoe-wan root cake \
    bandwidth $UPLINK \
    diffserv4 \
    dual-srchost \
    nat wash \
    ack-filter \
    split-gso \
    rtt 30ms \
    noatm \
    overhead $OVERHEAD \
    mpu $MPU

# Show status
tc -s qdisc show dev ifb-pppoe-wan
tc -s qdisc show dev pppoe-wan
