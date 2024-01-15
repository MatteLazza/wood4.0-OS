#!/bin/bash
name='Windows10'
interfaceclose="NO"
autoclose="NO"
autoopen="NO"
useconfig="NO"
keepopen=true

assignArguments () {
# For the flags that require flag + name, +1 has been added to increase the counter to the next flag
	for ((i = 1; i <= $#; i=i+1 )); do
		succ=$(($i+1))
	  	case ${!i} in
	  		-n | --name) name=${!succ}; i=$(($i+1));;
	  		-ic | --interfaceclose) interfaceclose="YES";;
	  		-ac | --autoclose) autoclose="YES";;
	  		-ao | --autoopen) autoopen="YES";;
	  		-c | --config) useconfig="YES";;
	  		*) echo "Illegal argument "${!i}; exit 1;;
	  	esac
	done
}



# Check whether user had supplied -h or --help . If yes display usage
if [[ $@ == "--help" ||  $@ == "-h" ]]
then 
	echo "Usage: ./Start_Machine.sh [arguments]"
	echo "Check ./Start_Machine.sh -l for all arguments"
	exit 0
fi 
# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ $@ == "--list" ||  $@ == "-l" ]]
then 
	data=("Command|Description|Default value" \
	"-n, --name <machine name>|Start the machine with the given name.|$name" \
	"-ic, --interfaceclose|Automatically shutdown host when guest interface close.|$interfaceclose" \
	"-ac, --autoclose|Automatically shutdown host when guest shutdown.|$autoclose" \
	"-ao, --autoopen|Open the interface if it has been closed while guest is still running.|$autoopen" \
	"-c, --config|Start the machine using the parameters in the config. Script will override already inserted flags|$useconfig" )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi 

# Assign flags that have been sent as arguments
assignArguments $@

# After getting all the arguments from command line, get all the flags from the config.file
if [[ $useconfig = "YES" ]]; then
	string_arg=$(cat /usr/local/sbin/Start_machine.conf)
	eval set -- "$(printf "%q " $string_arg)"
	assignArguments $@
fi


# Verify the name has been inserted
if [[ $name = "" ]]; then
	echo "Machine name cannot be empty."
	exit 1
fi

# Verify if there is already a machine with the given name
VMcreated=$(virsh list --all)
regexPattern="\s*.\s+$name\s+.*"
if ! [[ $VMcreated =~ $regexPattern ]]; then
	echo "There isn't any virtual machine with the name $name."
	exit 1
fi

# Start the virtual machine with the given name
virsh start $name > /dev/null 2>&1
while [ "$keepopen" = true ]
do
	virt-viewer $name -f --attach > /dev/null 2>&1
	
	# If this point has been reached, interface or guest system has been closed/shutdown.
	if [[ $interfaceclose == "YES" ]]; then
		virsh destroy $name
		#shutdown -h now
	fi
	# If interface was no but autoclose yes, we must check if the VM with the given name now has shut off
	if [[ $autoclose == "YES" ]]; then
		VMcreated=$(virsh list --all)
		regexPattern="\s*.\s+$name\s+shut off"
		if [[ $VMcreated =~ $regexPattern ]]; then
			#shutdown -h now
		fi
	fi
	
	# If user didn't set to keep the interface open, change the flag and free the loop
	if [[ $autoopen == "NO" ]]; then
		keepopen=false
	else
		# If autoopen is set to Yes and Interface is close, check if machine is down. If yes, interface haven't to open again
		VMcreated=$(virsh list --all)
		regexPattern="\s*.\s+$name\s+shut off"
		if [[ $VMcreated =~ $regexPattern ]]; then
			keepopen=false
		fi
	fi
done
exit 0














