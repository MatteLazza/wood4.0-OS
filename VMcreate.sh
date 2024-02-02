#!/bin/bash
name="Windows10"
memory=1
sockets=1
cores=1
threads=1
diskpath="/var/lib/libvirt/images/ubuntu22.04.qcow2"
bridge=virbr0
bridgemodel=virtio
ram=65536
vram=65536
vgamem=65536
memorychanged=false
free=300
scanningtimes=5
useconfig="NO"

assignArguments () {
	for ((i = 1; i <= $#; i=i+2 )); do
		succ=$(($i+1))
		case ${!i} in
			-n | --name) name=${!succ};;
			-m | --memory) memory=${!succ}; memorychanged=true;;
			-s | --sockets) sockets=${!succ};;
			-c | --cores) cores=${!succ};;
			-t | --threads) threads=${!succ};;
			-dp | --diskpath) diskpath=${!succ};;
			-b | --bridge) bridge=${!succ};;
			-bm | --bridgemodel) bridgemodel=${!succ};;
			-r | --ram) ram=${!succ};;
			-vr | --vram) vram=${!succ};;
			-vg | --vgamem) vgamem=${!succ};;
			--free) free=${!succ};;
  			--times) scanningtimes=${!succ};;
			--config) useconfig="YES";;
			*) echo "Illegal argument "${!i}; exit 1;;
		esac
	done
}


# Check whether user had supplied -h or --help . If yes display usage
if [[ $@ == "--help" ||  $@ == "-h" ]]
then 
	echo "Usage: ./VMcreate.sh [arguments]"
	echo "Check ./VMcreate.sh -l for all arguments"
	exit 0
fi 

# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ $@ == "--list" ||  $@ == "-l" ]]
then 
	data=("Command|Description|Default value" \
	"-n, --name <machine name>|Set the name of the machine.|$name" \
	"-m, --memory <amount>|Set the amount of memory given to the virtual machine (MB).|$memory" \
	"-s, --sockets <amount>|Set the number of sockets for the CPU.|$sockets" \
	"-c, --cores <amount>|Set the number of cores for the CPU.|$cores" \
	"-t, --threads <amount>|Set the number of threads for the CPU.|$threads" \
	"-dp, --diskpath <path>|Specify the path of the virtual disk.|$diskpath" \
	"-b, --bridge <network name>|Specify the network bridge type.|$bridge" \
	"-bm, --bridgemodel <model name>|Specify the network bridge model.|$bridgemodel" \
	"-r, --ram <amount>|Specify video ram for the video.|$ram" \
	"-vr, --vram <amount>|Specify the virtual ram for the video.|$vram" \
	"-vg, --vgamem <amount>|Specify the vgamem memory of the video.|$vgamem" \
	"--times <amount>|Specify the amount of times the memory have to be scanned before continuing the procedure. Large values mean more precision, but more time required.|$scanningtimes" \
	"--free <amount>|Specify the amount of free memory that will not be assigned to the virtual machine (MB).|$free" \
	"--config|Start the machine using the parameters in the config. Configs will override already inserted flags|$useconfig" )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi

# First part, always get the Thread/Core/Sockets from the machine. In case, later they will be reassigned
CPUspecifications=$(lscpu)
regexPattern="\bThread.s.\s*per\s*core:\s*([0-9]+)\b"
if [[ $CPUspecifications =~ $regexPattern ]]; then
	threads=${BASH_REMATCH[1]}
fi
regexPattern="\bCore.s.\s*per\s*socket:\s*([0-9]+)\b"
if [[ $CPUspecifications =~ $regexPattern ]]; then
	cores=${BASH_REMATCH[1]}
fi
regexPattern="\bSocket.s.:\s*([0-9]+)\b"
if [[ $CPUspecifications =~ $regexPattern ]]; then
	sockets=${BASH_REMATCH[1]}
fi


# Assign flags that have been sent as arguments
assignArguments $@

# After getting all the arguments from command line, get all the flags from the config.file
if [[ $useconfig = "YES" ]]; then
	string_arg=$(cat /usr/local/sbin/VMcreate.conf)
	eval set -- "$(printf "%q " $string_arg)"
	assignArguments $@
fi



# Verify if there is already a machine with the given name
VMcreated=$(virsh list --all)
regexPattern="\s*.\s+$name\s+.*"
if [[ $VMcreated =~ $regexPattern ]]; then echo "There is already a virtual machine with the name "$name; exit 1; fi
if [[ $memory -le 0 ]]; then echo "Error. Memory must be at least 1 MB."; exit 1; fi
if [[ $sockets -le 0 ]]; then echo "Error. Sockets must be at least 1."; exit 1; fi
if [[ $cores -le 0 ]]; then echo "Error. Cores must be at least 1."; exit 1; fi
if [[ $threads -le 0 ]]; then echo "Error. Threads must be at least 1."; exit 1; fi
if ! [[ -f "$diskpath" ]]; then echo "No disk found at path $diskpath"; exit 1; fi

# Verify bridge existing by using the command and verifying inserted one exists
bridgecommand=$(ip addr) 
regexPattern="[0-9]+:\s*$bridge"
if ! [[ $bridgecommand =~ $regexPattern ]]; then echo "Error. Bridge $bridge not found. Please make sure to select the right one using command ip addr and retry."; exit 1; fi
if [[ $ram -le 0 ]]; then echo "Error. Video ram must be at least 1 MB."; exit 1; fi # Is referred to video ram
if [[ $vram -le 0 ]]; then echo "Error. Video vram must be at least 1 MB."; exit 1; fi
if [[ $vgamem -le 0 ]]; then echo "Error. vgamem memory must be at least 1 MB."; exit 1; fi
if [[ $scanningtimes -le 0 ]]; then echo "times flag must be greater than 0"; exit 1; fi
if [[ $free -lt 0 ]]; then echo "free flag must be greater or equal to 0"; exit 1; fi


# If memory is not inserted, get the memory informations.
if [[ $memorychanged = false ]]; then
	echo "Gathering memory informations. It will take some time."
	memory=0 #reset memory
	for (( i=0; i < $scanningtimes; i++ ))
	do
		sleep 5
		# Get the memory and transform from kB to mB
		#MemTotal: total usable RAM
		#MemFree: free RAM, the memory which is not used for anything at all
		#MemAvailable: available RAM, the amount of memory available for allocation to any process
		RAMspecifications=$(cat /proc/meminfo)
		regexPattern="\MemAvailable:\s*([0-9]+)\b"
		if [[ $RAMspecifications =~ $regexPattern ]]; then
			memory=$(( memory + ${BASH_REMATCH[1]} / 1024 - free))
		fi
	done
	memory=$(( memory / scanningtimes ))
	echo "finished scanning."
fi


# Execute the install command with the given arguments
virt-install \
  --check path_in_use=off \
  --noautoconsole \
  --virt-type kvm \
  --name $name \
  --memory $memory \
  --vcpus $((sockets * cores * threads)),sockets=$sockets,cores=$cores,threads=$threads \
  --cpu host-passthrough \
  --disk path=$diskpath,bus=virtio \
  --network bridge=$bridge,model=$bridgemodel \
  --graphics spice \
  --video model=qxl,vgamem=$vgamem,ram=$ram,vram=$vram,heads=1 \
  --os-variant=win10 \
  --boot loader=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.ms.fd,menu=off > /dev/null
 
 #Verify if the virtual machine has been created. Check if there is a VM running with the given name.
VMcreated=$(virsh list)
regexPattern="\s*[0-9]+\s+$name\s+running"
if [[ $VMcreated =~ $regexPattern ]]; then
	echo "Virtual machine "$name" has been created and running."
	echo "Waiting for closure..."
	sleep 30

	virsh destroy $name > /dev/null 2>&1

	echo "System has been turned off and ready to be used."
	exit 0
else
    echo "No virtual machine created"
    exit 1
fi