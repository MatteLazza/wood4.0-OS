#!/bin/bash
declare -A usb

regex_ACTION="ACTION=(\S+)"
regex_GET_USB_NAME="ID_MODEL_FROM_DATABASE=(.+)"
while true; do
    # Monitor udev events
    udevadm monitor --subsystem-match=usb --property --udev | \
    while read -r line; do
        if [[ $line =~ $regex_GET_USB_NAME ]]; then
            echo "USB name: ${BASH_REMATCH[1]}"
        fi
    done
done
