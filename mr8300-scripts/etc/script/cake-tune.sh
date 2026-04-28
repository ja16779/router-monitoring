#!/bin/sh
# CAKE tuning script – GL-MT6000
# Egress: lan5 | Ingress: ifb4lan5

UPLINK="250Mbit"
DOWNLINK="250Mbit"
RTT="30ms"
OVERHEAD="22"

### EGRESS (UPLOAD) ###
tc qdisc replace dev lan1 root cake \
    bandwidth $UPLINK \
    diffserv4 \
    dual-srchost \
    nat wash \
    ack-filter \
    split-gso \
    rtt $RTT \
    overhead $OVERHEAD \
    noatm

### INGRESS (DOWNLOAD) ###
tc qdisc replace dev ifb-lan1 root cake \
    bandwidth $DOWNLINK \
    diffserv4 \
    dual-dsthost \
    nonat wash \
    ingress \
    split-gso \
    rtt $RTT \
    overhead $OVERHEAD \
    noatm

### STATUS ###
tc -s qdisc show dev lan1
tc -s qdisc show dev ifb-lan1
