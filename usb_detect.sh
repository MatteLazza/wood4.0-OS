#!/bin/bash

#                                           WARNING
#
# This version of the script works fine with USB devices that are installed AFTER the boot of the VM
#               The script will not recognize any USB device already inserted at the boot.
#           Also, some particular USB devices maybe could not be sent to the virtual machine.

action="-"
vendorID="-"
productSTRING='-'
productID="-"
skipDisconnect=false

# Regex used to extract the informations
regex_ACTION="ACTION=(\S+)"
regex_PRODUCT="PRODUCT=([a-zA-Z0-9]+\/([a-zA-Z0-9]+)\/[a-zA-Z0-9]+)"
regex_VENDOR="ID_VENDOR_ID=([a-zA-Z0-9]+)"


# When executed, remove all the previus configurations
rm -f /tmp/usb_devices_installed_* > /dev/null 2>&1
INSTALLED_USB=$(lsusb)


# Verify input name
if [[ $1 = "" ]]; then
    echo "No virtual machine passed."
    exit 1
fi
VMrunning=$(virsh list)
regexPattern="\s*[0-9]+\s+$1\s+running"
if ! [[ $VMrunning =~ $regexPattern ]]; then
    echo "No virtual machine running with the name $1."
    exit 1
fi

echo "Usb detector up and running!"

while true; do
    # Monitor udev events
    udevadm monitor --subsystem-match=usb --property --udev | \
    while read -r line; do
        # Get the value required for the xml and the action to execute        
        if [[ $line =~ $regex_ACTION ]]; then 
            action=${BASH_REMATCH[1]}
        fi
        if [[ $line =~ $regex_VENDOR ]]; then 
            vendorID=${BASH_REMATCH[1]}
        fi
        if [[ $line =~ $regex_PRODUCT ]]; then 
            productSTRING=${BASH_REMATCH[1]}
            productSTRING=${productSTRING//\//_} # Change the / to _ for later use as name
            productID=${BASH_REMATCH[2]}
        fi



        # Check for connections
        if [[ $line = "" && $action = "add" ]] || [[ $line = "" && $action = "bind" ]]; then
            newUSB=$(lsusb)
            differences=$(diff  <(echo "$INSTALLED_USB" ) <(echo "$newUSB"))
            if [[ $vendorID != "-" && $productID != "-" && $differences != "" ]]; then
echo "<hostdev mode='subsystem' type='usb' managed='yes'>
    <source>
    <vendor id='0x"$vendorID"'/>
    <product id='0x"$productID"'/>
    </source>
</hostdev>" | tee /tmp/usb_devices_installed_$productSTRING.xml > /dev/null
                        # Update the list of all usb devices installed in the machine
                virsh attach-device $1 --file /tmp/usb_devices_installed_$productSTRING.xml --live > /dev/null 2>&1
                INSTALLED_USB=$newUSB
                skipDisconnect=true
            fi
        fi

        #Check for disconnections
        if [[ $line = "" && $action = "remove" ]] || [[ $line = "" && $action = "unbind" ]]; then
            #Verify the data
            if [[ $action != "-" && $productID != "-" ]]; then
                #Disconnection also happen if the device is passed to the VM. in that case, skip the disconnection.
                if [[ $skipDisconnect = false ]]; then
                    virsh detach-device $1 --file /tmp/usb_devices_installed_$productSTRING.xml > /dev/null 2>&1
                    rm -f /tmp/usb_devices_installed_$productSTRING.xml > /dev/null 2>&1
                    INSTALLED_USB=$(lsusb)
                else
                    skipDisconnect=false
                fi
            fi
        fi



        # This must be the latest. Refresh the data
        if [[ $line = "" ]]; then
            action="-"
            vendorID="-"
            productSTRING="-"
            productID="-"
        fi
    done
done
