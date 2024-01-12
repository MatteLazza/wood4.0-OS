#!/bin/bash
# Change the path to the folder containing the Verisoner.sh 
exitstatus=0
machinename='win10-clone'
snapshotname1='working'
mode="a"


# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ ( $@ == "--list") ||  $@ == "-l" ]]
then 
	data=("Command|Description" \
	"-a, --all|Test all functions." \
	"-s, --snapshot|Test all snapshot functions." \
	"-r, --restore|Test all restore functions." \
	"-rem, --remove|Test all remove functions." \
	"-i, --info|Test all informations functions" \
	"-b, --basic|Test all basics functionalities." )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi 

# Check for input arguments and assign the variable with the given value
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
  		-a | --all) mode="a";;
  		-s | --snapshot) mode="s";;
  		-r | --restore) mode="r";;
  		-rem | --remove) mode="rem";;
  		-i | --info) mode="i";;
  		-b | --basic) mode="b";;
  	esac
done






noNameProvided() {
	messageresult=$(bash ./Versioner.sh -s)
	if ! [[ $messageresult = "Machine name cannot be empty." ]]; then
		echo "Error noNameProvided."
		echo "Expected: 'Machine name cannot be empty.'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}

notExists() {
	messageresult=$(bash ./Versioner.sh -s PleaseNobodyUseThisNameIWillBeSad)
	if ! [[ $messageresult = "There isn't any virtual machine with the name PleaseNobodyUseThisNameIWillBeSad." ]]; then
		echo "Error notExists."
		echo "Expected: 'There isn't any virtual machine with the name PleaseNobodyUseThisNameIWillBeSad.'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}

noFlag() {
	messageresult=$(bash ./Versioner.sh -PleaseNobodyUseThisNameIWillBeSad)
	if ! [[ $messageresult = "Illegal argument -PleaseNobodyUseThisNameIWillBeSad" ]]; then
		echo "Error noFlag."
		echo "Expected: 'Illegal argument -PleaseNobodyUseThisNameIWillBeSad'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}







wrongInfoSyntax() {
	messageresult=$(bash ./Versioner.sh -i $machinename)
	if ! [[ $messageresult = "You must use the -n flag to specify the snapshot name." ]]; then
		echo "Error wrongInfoSyntax."
		echo "Expected: 'You must use the -n flag to specify the snapshot name.'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}

infoNoSnapshot() {
	messageresult=$(bash ./Versioner.sh -i $machinename -n ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed)
	if ! [[ $messageresult = "No snapshot ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed found for the machine $machinename." ]]; then
		echo "Error infoNoSnapshot."
		echo "Expected: 'No snapshot ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed found for the machine $machinename.'"
		echo "Recived : '$messageresult'"
		exitstatus=1
	fi
}

infoSnapshot() {
	messageresult=$(bash ./Versioner.sh -i $machinename -n $snapshotname1)
	regexPattern="\bName:\s*$snapshotname1\s*Domain:\s*$machinename\b"
	if ! [[ $messageresult =~ $regexPattern ]]; then
		echo "Error infoSnapshot."
		echo "Expected: 'Name: working Domain: win10-clone ...'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
}







createSnapshot() {
	dateSnap=$(date '+%Y-%m-%d-%H-%M-%S')
	messageresult=$(bash ./Versioner.sh -s $machinename)
	if ! [[ $messageresult = "Snapshot $dateSnap created." ]]; then
		echo "Error createSnapshotAuto."
		echo "Expected: 'Snapshot $dateSnap created.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename > /dev/null 2>&1
	
	messageresult=$(bash ./Versioner.sh -s $machinename -n ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed)
	if ! [[ $messageresult = "Snapshot ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed created." ]]; then
		echo "Error createSnapshotNamed."
		echo "Expected: 'Snapshot ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed created.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename > /dev/null 2>&1
	
}

createSnapshotForceMachine() {
	virsh start $machinename > /dev/null 2>&1
	# Test creation with name
	messageresult=$(bash ./Versioner.sh -s $machinename -n IfYouSeeThisInSnapshotsItsAProblem -f)
	if ! [[ $messageresult = "Snapshot IfYouSeeThisInSnapshotsItsAProblem created." ]]; then
		echo "Error createSnapshotForceMachineRunning."
		echo "Expected: 'Snapshot IfYouSeeThisInSnapshotsItsAProblem created.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename -n IfYouSeeThisInSnapshotsItsAProblem > /dev/null 2>&1
	virsh destroy $machinename > /dev/null 2>&1
}

createSnapshotFailMachineRunning() {
	virsh start $machinename > /dev/null 2>&1
	# Test creation without specified name
	dateSnap=$(date '+%Y-%m-%d-%H-%M-%S')
	messageresult=$(bash ./Versioner.sh -s $machinename)
	if ! [[ $messageresult = "Virtual machine $machinename is running. Please make sure to turn it off and retry." ]]; then
		echo "Error createSnapshotFailMachineRunning with autoname."
		echo "Expected: 'Virtual machine $machinename is running. Please make sure to turn it off and retry.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	
	bash ./Versioner.sh -rem $machinename -n $dateSnap> /dev/null 2>&1
	# Test creation with name
	messageresult=$(bash ./Versioner.sh -s $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	if ! [[ $messageresult = "Virtual machine $machinename is running. Please make sure to turn it off and retry." ]]; then
		echo "Error createSnapshotFailMachineRunning with name."
		echo "Expected: 'Virtual machine $machinename is running. Please make sure to turn it off and retry.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename -n IfYouSeeThisInSnapshotsItsAProblem > /dev/null 2>&1
	virsh destroy $machinename > /dev/null 2>&1
}

createSnapshotFailAlreadyExisting() {
	messageresult=$(bash ./Versioner.sh -s $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	messageresult=$(bash ./Versioner.sh -s $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	if ! [[ $messageresult = "Snapshot IfYouSeeThisInSnapshotsItsAProblem already exists for the machine $machinename." ]]; then
		echo "Error createSnapshotFailAlreadyExisting."
		echo "Expected: 'Snapshot IfYouSeeThisInSnapshotsItsAProblem already exists for the machine $machinename.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename -n IfYouSeeThisInSnapshotsItsAProblem > /dev/null 2>&1
}







revertSnapshot() {
	dateSnap=$(date '+%Y-%m-%d-%H-%M-%S')
	bash ./Versioner.sh -s $machinename > /dev/null 2>&1
	messageresult=$(bash ./Versioner.sh -r $machinename)
	if ! [[ $messageresult = "Snapshot $dateSnap restored successfully." ]]; then
		echo "Error revertSnapshot autoname."
		echo "Expected: 'Snapshot $dateSnap restored successfully.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename -n $dateSnap > /dev/null 2>&1
	
	messageresult=$(bash ./Versioner.sh -s $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	messageresult=$(bash ./Versioner.sh -r $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	if ! [[ $messageresult = "Snapshot IfYouSeeThisInSnapshotsItsAProblem restored successfully." ]]; then
		echo "Error revertSnapshot named."
		echo "Expected: 'Snapshot IfYouSeeThisInSnapshotsItsAProblem restored successfully.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	bash ./Versioner.sh -rem $machinename -n IfYouSeeThisInSnapshotsItsAProblem > /dev/null 2>&1
}

revertSnapshotNameNotExists() {
	messageresult=$(bash ./Versioner.sh -r $machinename -n ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed)
	if ! [[ $messageresult = "No snapshot ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed found for the machine $machinename." ]]; then
		echo "Error revertSnapshotNameNotExists."
		echo "Expected: 'No snapshot ThisIsASnapshotNameReallyLongAndStupidThatIHopeWillNotBeUsed found for the machine $machinename.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
}







removeSnapshot() {
	dateSnap=$(date '+%Y-%m-%d-%H-%M-%S')
	bash ./Versioner.sh -s $machinename > /dev/null 2>&1
	messageresult=$(bash ./Versioner.sh -rem $machinename)
	if ! [[ $messageresult = "Snapshot $dateSnap deleted successfully." ]]; then
		echo "Error removeSnapshot autoname."
		echo "Expected: 'Snapshot $dateSnap deleted successfully.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
	
	bash ./Versioner.sh -s $machinename -n IfYouSeeThisInSnapshotsItsAProblem > /dev/null 2>&1
	messageresult=$(bash ./Versioner.sh -rem $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	if ! [[ $messageresult = "Snapshot IfYouSeeThisInSnapshotsItsAProblem deleted successfully." ]]; then
		echo "Error removeSnapshot named."
		echo "Expected: 'Snapshot IfYouSeeThisInSnapshotsItsAProblem deleted successfully.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
}

removeSnapshotFailNotExists() {
	messageresult=$(bash ./Versioner.sh -rem $machinename -n IfYouSeeThisInSnapshotsItsAProblem)
	if ! [[ $messageresult = "No snapshot IfYouSeeThisInSnapshotsItsAProblem found for the machine $machinename." ]]; then
		echo "Error removeSnapshotFailNotExists named."
		echo "Expected: 'No snapshot IfYouSeeThisInSnapshotsItsAProblem found for the machine $machinename.'"
		echo "Recived : '"$messageresult"'"
		exitstatus=1
	fi
}






case $mode in
	a)	noNameProvided
		notExists
		noFlag
		wrongInfoSyntax
		infoNoSnapshot
		infoSnapshot
		createSnapshot
		createSnapshotForceMachine
		createSnapshotFailMachineRunning
		createSnapshotFailAlreadyExisting
		revertSnapshot
		revertSnapshotNameNotExists
		removeSnapshot
		removeSnapshotFailNotExists
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
	
	
	s)	createSnapshot
		createSnapshotForceMachine
		createSnapshotFailMachineRunning
		createSnapshotFailAlreadyExisting
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
	
	
	r)	revertSnapshot
		revertSnapshotNameNotExists
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
	
	rem)removeSnapshot
		removeSnapshotFailNotExists
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
	i)	infoNoSnapshot
		infoSnapshot
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
	b)	noNameProvided
		notExists
		noFlag
		wrongInfoSyntax
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
esac
exit 0

"$@"



























	
