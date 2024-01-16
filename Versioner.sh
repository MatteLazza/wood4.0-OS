#!/bin/bash
machinename="-"
snapshotname="-"
snapshotdescription=" "
mode="-"
shutdownmode="NO"

getLatestSnapshot () {
	allsnapshots=$(virsh snapshot-list $machinename) #get all the snapshots, ordered by creation date
	regexPattern="[0-9]{4}-[0-9]{2}-[0-9]{2}.[0-9]{2}:[0-9]{2}:[0-9]{2}" # get all the date of the snapshots
		
	snapshotsbeforechanges=$allsnapshots
	latest_date=""
	# Use a loop to find all matches in the string
	while [[ $allsnapshots =~ $regexPattern ]]; do
		if [[ ${BASH_REMATCH[0]} > $latest_date ]]; then
			latest_date=${BASH_REMATCH[0]}
		fi
		# Update input_string to remove the matched date
		allsnapshots=${allsnapshots#*"${BASH_REMATCH[0]}"}
	done
	regexPattern="\S+\s+$latest_date"
	if ! [[ $snapshotsbeforechanges =~ $regexPattern ]]; then
		echo "There was an error while searching for the latest snapshot."
		exit 1
	fi
			
	snapshotdata=(${BASH_REMATCH// / }) #element 0 contains the name of the snapshot
	latestsnap=${snapshotdata[0]}
}


# Check whether user had supplied -h or --help . If yes display usage
if [[ $@ == "--help" ||  $@ == "-h" ]]
then 
	echo "Usage: ./Versioner.sh [arguments]"
	echo "Check ./Versioner.sh -l for all arguments"
	exit 0
fi 

# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ $@ == "--list" ||  $@ == "-l" ]]
then 
	data=("Command|Description|Default value" \
	"-s, --snapshot <machine name>|Take a snapshot of a given virtual machine.|$machinename" \
	"-r, --restore <machine name>|Apply the latest snapshot to a given virtual machine.|$machinename" \
	"-rem, --remove <machine name>|Delete a snapshot from a specified guest. If -n is not specified, latest will be deleted.|$machinename" \
	"-i, --info <machine name>|Get info of a specified snapshot passed by -n.|$machinename" \
	"-n, --name <snapshot name>|Specify the name of the snapshot.|$snapshotname" \
	"-d, --description <description test>|Specify a description for the snapshot.|$snapshotdescription" \
	"-f, --force|Force virtual machine to shutdown in case it's running while snapshot/restore.|$shutdownmode" \
	"-sh, --show <machine name>|Show all snapshots of the specified machine.|$machinename" )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi 

# Check for input arguments and assign the variable with the given value
# For the flags that only require the flag, -1 has been added for not getting the next flag
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
  		-s | --snapshot) machinename=${!succ}; mode="s";;
  		-r | --restore) machinename=${!succ}; mode="r";;
  		-rem | --remove) machinename=${!succ}; mode="rem";;
  		-i | --info) machinename=${!succ}; mode="i";;
  		-n | --name) snapshotname=${!succ};;
  		-d | --description) snapshotdescription=${!succ};;
  		-f | --force) shutdownmode="YES"; i=$(($i-1));;
  		-sh | --show) machinename=${!succ}; mode="show";;
  		*) echo "Illegal argument "${!i}; exit 1;;
  	esac
done

# Verify the name has been inserted
if [[ $machinename = "" ]]; then
	echo "Machine name cannot be empty."
	exit 1
fi

# Verify if there is already a machine with the given name
VMcreated=$(virsh list --all)
regexPattern="\s*.\s+$machinename\s+.*"
if ! [[ $VMcreated =~ $regexPattern ]]; then
	echo "There isn't any virtual machine with the name $machinename."
	exit 1
fi

# Based on the mode selected, execute the right action
case $mode in
	s)	# If name has not been selected, set default name as yyyy-mm-dd-HH-MM-SS. This value increase only.
		if [[ $snapshotname = "-" ]]; then
			snapshotname=$(date '+%Y-%m-%d-%H-%M-%S')
		fi
		
		# Verify if the name of the snapshot exists
		allsnapshots=$(virsh snapshot-list $machinename) #get all the snapshots, ordered by creation date
		regexPattern="\b$snapshotname\b" # get all the date of the snapshots
		if [[ $allsnapshots =~ $regexPattern ]]; then
			echo "Snapshot $snapshotname already exists for the machine $machinename."
			exit 1
		fi
		
		# Before taking the snapshot, check if the VM is running.
		VMcreated=$(virsh list)
		regexPattern="\s*[0-9]+\s+$machinename\s+running"
		if [[ $VMcreated =~ $regexPattern ]]; then
			# The machine is running. It's important to check the flag force to verify if terminate the procedure or force closure.
			if [[ $shutdownmode = "NO" ]]; then
				echo "Virtual machine $machinename is running. Please make sure to turn it off and retry."
				exit 1
			else
				virsh destroy $machinename > /dev/null 2>&1
				if [ $? -gt 0 ]; then
					echo "Error while shutting down the virtual machine."
					exit 1
				fi
			fi
		fi
		# After checking machine is turned off, perform the snapshot
		virsh snapshot-create-as --domain $machinename --name $snapshotname --description "$snapshotdescription" > /dev/null
		if [ $? -gt 0 ]; then
			echo "Error while making the snapshot."
			exit 1
		fi
		echo "Snapshot $snapshotname created.";;
		
		
	r) 	virsh destroy $machinename > /dev/null 2>&1
		# Get all the snapshots of a machine.
		allsnapshots=$(virsh snapshot-list $machinename) #get all the snapshots, ordered by creation date
		regexPattern="[0-9]{4}-[0-9]{2}-[0-9]{2}.[0-9]{2}:[0-9]{2}:[0-9]{2}" # get all the date of the snapshots
		
		# If there are no dates, return error because no snapshots are stored
		if ! [[ $allsnapshots =~ $regexPattern ]]; then
			echo "No snapshots found for the machine $machinename."
			exit 1
		fi
		
		# Verify the name of the snapshot. In case no name has been passed, get the latest snapshot available
		if [[ $snapshotname = "-" ]]; then
			getLatestSnapshot
			latest=$latestsnap
			virsh snapshot-revert --domain $machinename --snapshotname $latest > /dev/null
			if [ $? -gt 0 ]; then
				echo "There was an error while restoring snapshot."
				exit 1
			fi
			echo "Snapshot $latest restored successfully."
			exit 0
		fi
		
		# In case the name of the snapshot has been specified, verify if exists and then restore it
		regexPattern="\b$snapshotname\b" # get all the date of the snapshots
		if ! [[ $allsnapshots =~ $regexPattern ]]; then
			echo "No snapshot $snapshotname found for the machine $machinename."
			exit 1
		fi
		# After verifying the snapshot exists, procede to revert it.
		virsh snapshot-revert --domain $machinename --snapshotname $snapshotname > /dev/null
		if [ $? -gt 0 ]; then
			echo "There was an error while restoring snapshot."
			exit 1
		fi
		echo "Snapshot $snapshotname restored successfully.";;
		
		
	rem)	# Verify the name of the snapshot. In case no name has been passed, get the latest snapshot available
		allsnapshots=$(virsh snapshot-list $machinename) #get all the snapshots, ordered by creation date
		regexPattern="[0-9]{4}-[0-9]{2}-[0-9]{2}.[0-9]{2}:[0-9]{2}:[0-9]{2}" # get all the date of the snapshots
		
		# If there are no dates, return error because no snapshots are stored
		if ! [[ $allsnapshots =~ $regexPattern ]]; then
			echo "No snapshots found for the machine $machinename."
			exit 1
		fi
		if [[ $snapshotname = "-" ]]; then
			getLatestSnapshot
			latest=$latestsnap
			# After getting the latest snapshot, delete it
			virsh snapshot-delete $machinename $latest > /dev/null
			if [ $? -gt 0 ]; then
				echo "There was an error while deleting snapshot."
				exit 1
			fi
			echo "Snapshot $latest deleted successfully."
			exit 0
		fi
		
		# In case the name of the snapshot has been specified, verify if exists
		regexPattern="\b$snapshotname\b" # get all the date of the snapshots
		if ! [[ $allsnapshots =~ $regexPattern ]]; then
			echo "No snapshot $snapshotname found for the machine $machinename."
			exit 1
		fi
		#After verifying snapshot exists, procede to delete it.
		virsh snapshot-delete $machinename $snapshotname > /dev/null
		if [ $? -gt 0 ]; then
			echo "There was an error while deleting snapshot."
			exit 1
		fi
		echo "Snapshot $snapshotname deleted successfully.";;
		
	
	i) 	if [[ $snapshotname = "-" ]]; then
			echo "You must use the -n flag to specify the snapshot name."
			exit 1
		fi
		
		# In case the name of the snapshot has been specified, verify if exists
		allsnapshots=$(virsh snapshot-list $machinename) #get all the snapshots, ordered by creation date
		regexPattern="\b$snapshotname\b" # get all the date of the snapshots
		if ! [[ $allsnapshots =~ $regexPattern ]]; then
			echo "No snapshot $snapshotname found for the machine $machinename."
			exit 1
		fi
		virsh snapshot-info $machinename --snapshotname $snapshotname
		exit 0;;
	
		
	show) 	virsh snapshot-list $machinename;;
	
	
	*) echo "Select a valid functionality. Check ./Versioner.sh -l for all arguments."
	   exit 1;;
esac
exit 0