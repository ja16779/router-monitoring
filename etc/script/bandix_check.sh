#!/bin/sh

# Define fallback script path
FALLBACK_SCRIPT="/etc/script/bandix.sh"

# Check if bandix is installed
if opkg list-installed | grep -q "^bandix "; then
    echo "✅ bandix is already installed."
else
    echo "⚠️ bandix not found. Running fallback script..."
    if [ -x "$FALLBACK_SCRIPT" ]; then
        "$FALLBACK_SCRIPT"
    else
        echo "❌ Fallback script not found or not executable: $FALLBACK_SCRIPT"
    fi
fi
