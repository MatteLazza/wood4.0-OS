#!/bin/bash
name="Windows10"
memory=8192
sockets=1
cores=1
threads=1
diskpath="/var/lib/libvirt/images/win10.qcow2"
bridge=virbr0
bridgemodel=virtio
ram=65536
vram=65536
vgamem=65536

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
	"-vg, --vgamem <amount>|Specify the vgamem memory of the video.|$vgamem" )
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

# Check for input arguments and assign the variable with the given value
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
  		-n | --name) name=${!succ};;
  		-m | --memory) memory=${!succ};;
  		-s | --sockets) sockets=${!succ};;
  		-c | --cores) cores=${!succ};;
  		-t | --threads) threads=${!succ};;
  		-dp | --diskpath) diskpath=${!succ};;
  		-b | --bridge) bridge=${!succ};;
  		-bm | --bridgemodel) bridgemodel=${!succ};;
  		-r | --ram) ram=${!succ};;
  		-vr | --vram) vram=${!succ};;
  		-vg | --vgamem) vgamem=${!succ};;
  		*) echo "Illegal argument "${!i}; exit 1;;
  	esac
done

# Verify if there is already a machine with the given name
VMcreated=$(virsh list --all)
regexPattern="\s*.\s+$name\s+.*"
if [[ $VMcreated =~ $regexPattern ]]; then
	echo "There is already a virtual machine with the name "$name
	exit 1
fi

# Verify memory > 0
if [[ $memory -le 0 ]]; then
	echo "Error. Memory must be at least 1 MB."
	exit 1
fi

# Verify sockets > 0
if [[ $sockets -le 0 ]]; then
	echo "Error. Sockets must be at least 1."
	exit 1
fi

# Verify cores > 0
if [[ $cores -le 0 ]]; then
	echo "Error. Cores must be at least 1."
	exit 1
fi

# Verify threads > 0
if [[ $threads -le 0 ]]; then
	echo "Error. Threads must be at least 1."
	exit 1
fi

# Verify specified disk exists
if ! [[ -f "$diskpath" ]]; then
    echo "No disk found at path $diskpath"
    exit 1
fi

# Verify bridge
bridgecommand=$(ip addr) 
regexPattern="[0-9]+:\s*$bridge" # get all the date of the snapshots
if ! [[ $bridgecommand =~ $regexPattern ]]; then
	echo "Error. Bridge $bridge not found. Please make sure to select the right one using command ip addr and retry."
	exit 1
fi

# Verify ram > 0
if [[ $ram -le 0 ]]; then
	echo "Error. Video ram must be at least 1 MB."
	exit 1
fi
# Verify vram > 0
if [[ $vram -le 0 ]]; then
	echo "Error. Video vram must be at least 1 MB."
	exit 1
fi

# Verify vgamem > 0
if [[ $vgamem -le 0 ]]; then
	echo "Error. vgamem memory must be at least 1 MB."
	exit 1
fi

# Execute the install command with the given arguments
virt-install \
  --check path_in_use=off \
  --noautoconsole \
  --autostart \
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
  --boot loader=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.ms.fd,menu=on > /dev/null 2>&1
 
 #Verify if the virtual machine has been created. Check if there is a VM running with the given name.
VMcreated=$(virsh list)
regexPattern="\s*[0-9]+\s+$name\s+running"
if [[ $VMcreated =~ $regexPattern ]]; then
	echo "Virtual machine "$name" has been created and it's running."
	exit 0
else
    echo "No virtual machine created"
    exit 1
fi