#!/bin/bash
set -euo pipefail

alias_name="$1"
BT_CONFIG="$HOME/.config/bt-devices.conf"

if [ ! -f "$BT_CONFIG" ]; then
    echo "ERROR: $BT_CONFIG not found"
    exit 1
fi

device_address=$(grep "^${alias_name}=" "$BT_CONFIG" | cut -d'=' -f2)

if [ -z "$device_address" ]; then
    echo "ERROR: alias '${alias_name}' not found in $BT_CONFIG"
    exit 1
fi

connection_status=$(bluetoothctl info "$device_address" 2>/dev/null | grep "Connected:" | awk '{print $2}')

if [ "$connection_status" == "yes" ]; then
    echo "Disconnecting ${alias_name} (${device_address})..."
    bluetoothctl disconnect "$device_address"
else
    echo "Connecting ${alias_name} (${device_address})..."
    bluetoothctl connect "$device_address"
fi
