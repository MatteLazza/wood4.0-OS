#!/bin/bash
action=""

regex_ACTION="ACTION=(\S+)"
regex_GET_IDS="ID (([a-zA-Z0-9]+):([a-zA-Z0-9]+))"

# It's important to copy the default devices and never work on the original.
rm -f /tmp/usb_devices_installed.* > /dev/null 2>&1
cp /usr/local/sbin/usb_devices.list /tmp/usb_devices_installed.list



while true; do
    # Monitor udev events
    udevadm monitor --subsystem-match=usb --property --udev | \
    while read -r line; do
        # When a new USB has been added/removed, we have to check the action and get the id of the device
        if [[ $line =~ $regex_ACTION ]]; then 
            action=${BASH_REMATCH[1]}
            
            # Based on the action, decide if we have to add the USB or remove it.
            if [[ $action = "add" || $action = "bind" ]]; then
            # When an USB is added, it get the differences with the actual USB install list.
            # With the difference, it get the ids and add them to the file
                INSTALLED_USB=$(cat /tmp/usb_devices_installed.list)

                # Display differences
                newUSB=$(lsusb)
                differences=$(diff  <(echo "$INSTALLED_USB" ) <(echo "$newUSB"))

                # Match with the differences to get the IDs required
                if [[ $differences =~ $regex_GET_IDS ]]; then
                    # ID String=${BASH_REMATCH[0]}
                    # full_ID=${BASH_REMATCH[1]}
                    # vendorID=${BASH_REMATCH[2]}
                    # productID=${BASH_REMATCH[3]}

                        #write the file containing all the informations of the USB to be passed in kvm
echo "<hostdev mode='subsystem' type='usb' managed='yes'>
    <source>
    <vendor id='0x"${BASH_REMATCH[2]}"'/>
    <product id='0x"${BASH_REMATCH[3]}"'/>
    </source>
</hostdev>" | tee -a /tmp/usb_devices_installed.xml > /dev/null
                    # Update the list of all usb devices installed in the machine
                    lsusb | tee /tmp/usb_devices_installed.list > /dev/null

                    echo "DEBUG: dispositivo aggiunto!"
                fi
            else
                INSTALLED_USB=$(cat /tmp/usb_devices_installed.list)

                # Display differences
                newUSB=$(lsusb)
                differences=$(diff  <(echo "$INSTALLED_USB" ) <(echo "$newUSB"))

                echo "DEBUG: dispositivo rimosso $differences"
                cat /tmp/usb_devices_installed.xml
            fi
        fi


    done
done
