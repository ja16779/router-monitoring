#!/bin/sh

leases_file="/tmp/dhcp.leases"
leases_cache="/tmp/dhcp.leases.cache"

# Check if the file is updated
if ! cmp -s "$leases_file" "$leases_cache"; then
    # Log that the file has updates
    logger -p local0.info -t dhcp-join-notify "Updates detected in $leases_file. Executing SCP command..."

    # Execute SCP command
    sshpass -p admin scp "$leases_file" root@192.168.10.2:/tmp/
    if [ $? -eq 0 ]; then
        logger -p local0.info -t dhcp-join-notify "SCP command executed successfully"
        # Update the cached file to match the current file
        cp "$leases_file" "$leases_cache"
    else
        logger -p local0.info -t dhcp-join-notify "SCP command failed"
    fi
else
    # Log that there are no updates
    logger -p local0.info -t dhcp-join-notify "No updates detected in $leases_file. Skipping SCP command."
fi
