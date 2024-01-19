#!/bin/bash
autostartmode=false;
name='Windows10'
interfaceclose="NO"
autoclose="NO"
autoopen="NO"
keepopen=true
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
free=300
scanningtimes=5
noinstall=false

# check whether user had supplied -h or --help . If yes display usage
if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then 
	echo "Usage: ./Platform_Install.sh"
	echo "Check ./Platform_Install.sh -d/--download for the packages that will be installed"
	echo "Check ./Platform_Install.sh -l for all arguments"
	exit 0
fi 
# check whether user had supplied -d or --download . If yes display all packages that will be downloaded
if [[ ( $@ == "--download") ||  $@ == "-d" ]]
then 
	echo "List of all packages that will be installed:"
	echo "qemu-kvm"
	echo "qemu-utils"
	echo "libvirt-daemon-system"
	echo "libvirt-clients"
	echo "bridge-utils"
	echo "virt-manager"
	echo "ovmf"
	exit 0
fi

# Check whether user had supplied -l or --list . If yes display list of arguments
if [[ $@ == "--list" ||  $@ == "-l" ]]
then 
	data=("Command|Description|Default value" \
	"-a, --automatic |Enable automatic startup of the virtual machine at OS boot" \
	"-n, --name <machine name>|Start the machine with the given name.|$name" \
	"-ic, --interfaceclose|Automatically shutdown host when guest interface close.|$interfaceclose" \
	"-ac, --autoclose|Automatically shutdown host when guest shutdown.|$autoclose" \
	"-ao, --autoopen|Open the interface if it has been closed while guest is still running.|$autoopen" \
	"||" \
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
	"--free <amount>|Specify the amount of free memory that will not be assigned to the virtual machine (MB).|$free" \
	"--times <amount>|Specify the amount of times the memory have to be scanned before continuing the procedure. Large values mean more precision, but more time required.|$scanningtimes" \
	"--noinstall|Virtual machine will not be automatically installed.|$noinstall" )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
fi 

# Before evaluating any other flag, we must check if times and free are inserted. Those are required for basic calculation
# Also we take in consideration if memory has been selected, because if yes the calculation process will be reduced
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
		-m | --memory) memory="inserted";;
  		--free) free=${!succ};;
  		--times) scanningtimes=${!succ};;
  	esac
done

#Verify flags
if [[ $scanningtimes -le 0 ]]; then echo "times flag must be greater than 0"; exit 1; fi
if [[ $free -lt 0 ]]; then echo "free flag must be greater or equal to 0"; exit 1; fi

# If memory is not inserted, get the memory informations.
if [[ $memory != "inserted" ]]; then
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
fi

# Get the host thread/core/sockets configuration
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

# Check for input arguments and assign the variable with the given value.
# For the flags that only require the flag, -1 has been added for not getting the next flag
for ((i = 1; i <= $#; i=i+2 )); do
	succ=$(($i+1))
  	case ${!i} in
  		-a | --automatic) autostartmode=true; i=$(($i-1));;
  		-n | --name) name=${!succ};;
  		-ic | --interfaceclose) interfaceclose="YES"; i=$(($i-1));;
  		-ac | --autoclose) autoclose="YES"; i=$(($i-1));;
  		-ao | --autoopen) autoopen="YES"; i=$(($i-1));;
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
		--noinstall) noinstall=true; i=$(($i-1));;
  		*) echo "Illegal argument "${!i}; exit 1;;
  	esac
done

# Creationg of the start_machine.conf file, with the starting configuration of the machine.
startconfig="-n $name"
if [[ $interfaceclose = "YES" ]]; then startconfig="${startconfig} -ic"; fi
if [[ $autoclose = "YES" ]]; then startconfig="${startconfig} -ac"; fi
if [[ $autoopen = "YES" ]]; then startconfig="${startconfig} -ic"; fi
echo "$startconfig" | sudo tee /usr/local/sbin/Start_machine.conf > /dev/null 2>&1
# Verify file has been created
verifycreation=$(cat /usr/local/sbin/Start_machine.conf)
regexPattern="^cat:\s*\/usr\/local\/sbin\/Start_machine.conf\s*:\b"
if [[ $verifycreation =~ $regexPattern ]]; then
	echo "File Start_machine.conf cound't be created. Shutting down procedure."
	exit 1
fi

# Creation of the VMcreafe.conf with all the information related to the creation of the VM
echo "-n $name -m $memory -s $sockets -c $cores -t $threads -dp $diskpath -b $bridge -bm $bridgemodel -r $ram -vr $vram -vg $vgamem" | sudo tee /usr/local/sbin/VMcreate.conf > /dev/null 2>&1
# Verify file has been created
verifycreation=$(cat /usr/local/sbin/VMcreate.conf)
regexPattern="^cat:\s*\/usr\/local\/sbin\/VMcreate.conf\s*:\b"
if [[ $verifycreation =~ $regexPattern ]]; then
	echo "File VMcreate.conf cound't be created. Shutting down procedure."
	exit 1
fi

# Setup of the start script
userexecuting=$(whoami)
echo "[Unit]
Description=Automatic virtual machine startup at boot.

[Service]
ExecStart=/home/$userexecuting/Start_Machine.sh --config

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/VM-Autostart.service > /dev/null 2>&1

verifycreation=$(cat /etc/systemd/system/VM-Autostart.service)
regexPattern="^cat:\s*\/etc\/systemd\/system\/VM-Autostart.service\s*:\b"
if [[ $verifycreation =~ $regexPattern ]]; then
	echo "File VM-Autostart.service cound't be created. Shutting down procedure."
	exit 1
fi


if [[ $autostartmode = true ]]; then
	sudo systemctl daemon-reload
	sudo systemctl enable VM-Autostart.service
	if [ $? -gt 0 ]; then
		echo "Error while enabling virtual machine autostart service. Shutting down procedure."
		exit 1
	fi
	echo "Startup service enabled."
else
	echo "Autostart is disabled."
	echo "You can always turn it on by using 'systemctl enable VM-Autostart.service' and restart."
fi


#Setup all the requirements packages. Discard the output of the update
sudo apt update > /dev/null 2>&1
sudo apt install qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf -y
#verify that the command ended with 0. Otherwise, return error
if [ $? -gt 0 ]; then
	echo "Error with setup."
	exit 1
fi

echo "Packages installed."

#Enable libvirt deamon
sudo systemctl enable --now libvirtd
#Verify that the command ended with 0. Otherwise, return error
if [ $? -gt 0 ]; then
	echo "Error while enabling libvirt deamon."
	exit 1
fi
echo "Libvirt deamon enabled"

if [[ $noinstall = false ]]; then
	bash ./VMcreate.sh --config
fi

exit 0