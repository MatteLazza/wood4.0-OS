#!/bin/bash 
diskPath=""

# Check whether user had supplied -h or --help . If yes display usage
if [[ $@ == "--help" ||  $@ == "-h" ]]
then 
	echo "Usage: ./Expand_Disk.sh [virtual machine name] [total size (GB)]"
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


# Verify if the virtual machine is running
VMcreated=$(virsh list)
regexPattern="\s*[0-9]+\s+$1\s+running"
if [[ $VMcreated =~ $regexPattern ]]; then echo "Virtual machine $1 is running. Shut it down and retry."; exit 1; fi


#Get the informations of the virtual machine disk location
diskPath=$(virsh domblklist $1)
echo $diskPath
#Verify match if string contains required data
regexPattern="[a-zA-Z0-9\/.]+\/.+.qcow2"
if ! [[ $diskPath =~ $regexPattern ]]; then
	echo "Error while getting inforations from the virtual machine."
	exit 1
fi


diskPath=${BASH_REMATCH[0]}
#Get the partitions of the virtual machine
diskData=$(sudo virt-filesystems --long --parts --blkdevs -h -a $diskPath)
diskPath=${diskPath%".qcow2"}


#Verify match if string contains all the necessary informations
regexPattern="(\/dev\/sda[0-9]+)\s+[a-z]+\s+.\s+([0-9,.]+)([MGT])"
if ! [[ $diskData =~ $regexPattern ]]; then
	echo "Error while getting the partitions"
	exit 1
fi


# With all the partitions, it's important to get the one with the most GB.
# The partition with most GB is the one with all the data.
biggestData=0
partitionName=""
while [[ $diskData =~ $regexPattern ]]; do
	mem=${BASH_REMATCH[2]}
	case ${BASH_REMATCH[3]} in
		M) mem=$((mem*1024));;
		G) mem=$((mem*1048576));;
		T) mem=$((mem*1073741824));;
	esac
	if [[ $mem -gt $biggestData ]]; then
		biggestData=$mem
		partitionName=${BASH_REMATCH[1]}
	fi
	# Update input_string to remove the matched date
	diskData=${diskData#*"${BASH_REMATCH[0]}"}
done


# After gathering all the informations, create the new disk
sudo qemu-img create -f qcow2 $diskPath-Increased.qcow2 "$2"G
sudo virt-resize --expand $partitionName $diskPath.qcow2 $diskPath-Increased.qcow2
virt-xml $1 --edit --disk=$diskPath-Increased.qcow2