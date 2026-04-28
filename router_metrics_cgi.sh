#!/bin/sh
echo "HTTP/1.1 200 OK"
echo "Content-Type: text/plain; charset=utf-8"
echo ""
/usr/bin/router_exporter.sh 2>/dev/null
