#!/bin/bash
diskPath=""

# Check whether user had supplied -h or --help . If yes display usage
if [[ $@ == "--help" ||  $@ == "-h" ]]
then 
	echo "Usage: ./Expand_Disk.sh [virtual machine name] [increase amount (GB)]"
	exit 0
fi
# Verify the name has been inserted
if [[ $1 = "" ]]; then echo "Machine name cannot be empty."; exit 1; fi
if [[ $2 = "" ]]; then echo "Increase amount cannot be empty."; exit 1; fi

# Verify if there is already a machine with the given name
regexPattern="[a-zA-Z]"
if [[ $2 =~ $regexPattern ]]; then echo "The amount must be a number"; exit 1; fi


# Verify if there is already a machine with the given name
VMcreated=$(virsh list --all)
regexPattern="\s*.\s+$1\s+.*"
if ! [[ $VMcreated =~ $regexPattern ]]; then echo "There isn't any virtual machine with the name $1."; exit 1; fi

VMcreated=$(virsh list)
regexPattern="\s*[0-9]+\s+$1\s+running"
if [[ $VMcreated =~ $regexPattern ]]; then echo "Virtual machine $1 is running. Shut it down and retry."; exit 1; fi


diskPath=$(virsh domblklist $1)
echo $diskPath

regexPattern="\/\S+(\/[\S]+).qcow2"
if [[ $1 =~ $regexPattern ]]; then
    
    
fi