#!/bin/bash
exitstatus=0
mode="a"

# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ ( $@ == "--list") ||  $@ == "-l" ]]
then 
	data=("Command|Description" \
	"-a, --all|Test all functions." )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi 

# Check for input arguments and assign the variable with the given value
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
  		-a | --all) mode="a";;
  	esac
done


noNameProvided() {
	messageresult=$(bash ./Start_Machine.sh -n)
	expected="Machine name cannot be empty."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error noNameProvided."
		echo "Expected: '$expected'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}

noMachineExists() {
	messageresult=$(bash ./Start_Machine.sh -n ThisIsTheNameOfaMachineThatIsStupidAndForTesting)
	expected="There isn't any virtual machine with the name ThisIsTheNameOfaMachineThatIsStupidAndForTesting."
	if ! [[ $messageresult = $expected ]]; then
		echo "Error noMachineExists."
		echo "Expected: '$expected'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}

illegalArgument() {
	messageresult=$(bash ./Start_Machine.sh -)
	expected="Illegal argument -"
	if ! [[ $messageresult = $expected ]]; then
		echo "Error illegalArgument."
		echo "Expected: '$expected'"
		echo "Recived : 'Recived: '$messageresult'"
		exitstatus=1
	fi
}




case $mode in
	a)	noNameProvided
		noMachineExists
		illegalArgument
		if [[ $exitstatus -eq 0 ]]; then echo "All tests passed!"; else echo "Some tests failed. Please read log above."; fi;;
		
esac
exit 0


"$@"










