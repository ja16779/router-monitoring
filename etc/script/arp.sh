#!/bin/bash
for entry in $(ip neigh show | grep FAILED | awk '{print $1}'); do
    ip neigh delete $entry dev br-lan
done
