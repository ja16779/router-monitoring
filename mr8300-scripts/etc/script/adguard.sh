#!/bin/sh
# shellcheck shell=dash
# NOTE: 'echo $SHELL' reports '/bin/ash' on the routers, see:
# - https://en.wikipedia.org/wiki/Almquist_shell#Embedded_Linux
# - https://github.com/koalaman/shellcheck/issues/1841
#
# Description: This script updates AdGuardHome to the latest version.
# Thread: https://forum.gl-inet.com/t/how-to-update-adguard-home-testing/39398
# Author: Admon
# Date: 2024-03-13
SCRIPT_VERSION="2024.11.23.01"
SCRIPT_NAME="update-adguardhome.sh"
UPDATE_URL="https://raw.githubusercontent.com/Admonstrator/glinet-adguard-updater/main/update-adguardhome.sh"
AGH_TINY_URL="https://github.com/Admonstrator/glinet-adguard-updater/releases/latest/download"
#
# Usage: ./update-adguardhome.sh [--ignore-free-space] [--select-release]
# Warning: This script might potentially harm your router. Use it at your own risk.
#
# Populate variables

 TOKEN="REDACTED_BOT_TOKEN"
 ID="716542586"
 URL="https://api.telegram.org/bot$TOKEN/sendMessage"

TEMP_FILE="/tmp/AdGuardHomeNew"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
INFO='\033[0m' # No Color
IGNORE_FREE_SPACE=0
SELECT_RELEASE=0

    AGH_VERSION_NEW=$(curl -L -s $AGH_TINY_URL/version.txt | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
    if [ -z "$AGH_VERSION_NEW" ]; then
        echo "ERROR" "Could not get latest AdGuard Home version. Please check your internet connection."
        exit 1
    fi
    echo "INFO" "Latest AdGuard Home version: $AGH_VERSION_NEW"
    AGH_VERSION_OLD=$(/usr/bin/AdGuardHome --version | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
    echo "INFO" "Current AdGuard Home version: $AGH_VERSION_OLD"
        if [ "$AGH_VERSION_NEW" == "$AGH_VERSION_OLD" ]; then
        echo "SUCCESS" "You already have the latest version."
        exit 0
    fi

MESSAGE="AdGuard Home Update Available: Current Version: $AGH_VERSION_OLD, New Version: $AGH_VERSION_NEW"
curl -s -X POST $URL -d chat_id=$ID -d text="$MESSAGE" > /dev/null
