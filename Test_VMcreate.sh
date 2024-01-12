#!/bin/bash
exitstatus=0
mode="a"

# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ ( $@ == "--list") ||  $@ == "-l" ]]
then 
	data=("Command|Description" \
	"-a, --all|Test all functions." \
	"-c, --creation|Test the creation of the virtual machine")
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi 

# Check for input arguments and assign the variable with the given value
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
  		-a | --all) mode="a";;
  		-c | --creation) mode="c";;
  	esac
done


illegalArgument() {
	messageresult=$(bash ./VMcreate.sh -)
	expected="Illegal argument -"
	if ! [[ $messageresult = $expected ]]; then
		echo "Error illegalArgument."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyMemory() {
	messageresult=$(bash ./VMcreate.sh -m 0)
	expected="Error. Memory must be at least 1 MB."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyMemory."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifySockets() {
	messageresult=$(bash ./VMcreate.sh -s 0)
	expected="Error. Sockets must be at least 1."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifySockets."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyCores() {
	messageresult=$(bash ./VMcreate.sh -c 0)
	expected="Error. Cores must be at least 1."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyCores."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyThreads() {
	messageresult=$(bash ./VMcreate.sh -t 0)
	expected="Error. Threads must be at least 1."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyThreads."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyDisk() {
	messageresult=$(bash ./VMcreate.sh -dp notExistingPath)
	expected="No disk found at path notExistingPath"
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyDisk."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyBridge() {
	messageresult=$(bash ./VMcreate.sh -b notExistingBridge)
	expected="Error. Bridge notExistingBridge not found. Please make sure to select the right one using command ip addr and retry."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyBridge."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyVideoRam() {
	messageresult=$(bash ./VMcreate.sh -r 0)
	expected="Error. Video ram must be at least 1 MB."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyVideoRam."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyVideoVram() {
	messageresult=$(bash ./VMcreate.sh -vr 0)
	expected="Error. Video vram must be at least 1 MB."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyVideoVram."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

verifyVideovgamem() {
	messageresult=$(bash ./VMcreate.sh -vg 0)
	expected="Error. vgamem memory must be at least 1 MB."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error verifyVideovgamem."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

successCreation() {
	messageresult=$(bash ./VMcreate.sh -n NameOfTheMachineThatShouldNotExists)
	expected="Virtual machine NameOfTheMachineThatShouldNotExists has been created and it's running."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error successCreation."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
	sleep 1
	virsh destroy NameOfTheMachineThatShouldNotExists > /dev/null 2>&1
	sleep 1
	virsh undefine --nvram NameOfTheMachineThatShouldNotExists > /dev/null 2>&1
}

errorCreationNameExists() {
	messageresult=$(bash ./VMcreate.sh -n NameOfTheMachineThatShouldNotExists)
	expected="Virtual machine NameOfTheMachineThatShouldNotExists has been created and it's running."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error errorCreationNameExists."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
	messageresult=$(bash ./VMcreate.sh -n NameOfTheMachineThatShouldNotExists)
	expected="There is already a virtual machine with the name NameOfTheMachineThatShouldNotExists"
	if ! [[ $messageresult = $expected ]]; then
		echo "Error errorCreationNameExists."
		echo "Expected: '$expected'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
	sleep 1
	virsh destroy NameOfTheMachineThatShouldNotExists > /dev/null 2>&1
	sleep 1
	virsh undefine --nvram NameOfTheMachineThatShouldNotExists > /dev/null 2>&1
}


case $mode in
	a)	illegalArgument
		verifyMemory
		verifySockets
		verifyCores
		verifyThreads
		verifyDisk
		verifyBridge
		verifyVideoRam
		verifyVideoVram
		verifyVideovgamem
		successCreation
		errorCreationNameExists
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
	c)	successCreation
		errorCreationNameExists
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
esac
exit 0




"$@"










