#!/usr/bin/expect
set timeout 10
set password "admin"

spawn scp /tmp/dhcp.leases root@192.168.8.2:/tmp/
expect "password:"
send "$password\r"
expect eof
