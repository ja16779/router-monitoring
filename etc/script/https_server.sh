#!/bin/sh

# Check if uhttpd is running with the specified port and directory
if ! ps | grep "[u]httpd -p 8000 -h /tmp/" > /dev/null; then
    echo "uhttpd is not running. Starting it now..."
    uhttpd -p 8000 -h /tmp/
else
    echo "uhttpd is already running."
fi
