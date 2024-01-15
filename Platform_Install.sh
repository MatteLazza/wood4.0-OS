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
	"-m, --memory|Set the amount of memory given to the virtual machine (MB).|$memory" \
	"-s, --sockets|Set the number of sockets for the CPU.|$sockets" \
	"-c, --cores|Set the number of cores for the CPU.|$cores" \
	"-t, --threads|Set the number of threads for the CPU.|$threads" \
	"-dp, --diskpath|Specify the path of the virtual disk.|$diskpath" \
	"-b, --bridge|Specify the network bridge type.|$bridge" \
	"-bm, --bridgemodel|Specify the network bridge model.|$bridgemodel" \
	"-r, --ram|Specify video ram for the video.|$ram" \
	"-vr, --vram|Specify the virtual ram for the video.|$vram" \
	"-vg, --vgamem|Specify the vgamem memory of the video.|$vgamem" )
	printf "%s\n" "${data[@]}" | column -t -s '|'
	exit 0
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

# Get the memory and transform from kB to mB
RAMspecifications=$(cat /proc/meminfo)
regexPattern="\bMemTotal:\s*([0-9]+)\b"
if [[ $RAMspecifications =~ $regexPattern ]]; then
	memory=$(( ${BASH_REMATCH[1]} / 1024 ))
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
echo "-m $memory -s $sockets -c $cores -t $threads -dp $diskpath -b $bridge -bm $bridgemodel -r $ram -vr $vram -vg $vgamem" | sudo tee /usr/local/sbin/VMcreate.conf > /dev/null 2>&1
# Verify file has been created
verifycreation=$(cat /usr/local/sbin/VMcreate.conf)
regexPattern="^cat:\s*\/usr\/local\/sbin\/VMcreate.conf\s*:\b"
if [[ $verifycreation =~ $regexPattern ]]; then
	echo "File VMcreate.conf cound't be created. Shutting down procedure."
	exit 1
fi



#TODO
exit 0


# Setup of the start script
userexecuting=$(whoami)
echo "[Unit]
Description=Automatic virtual machine startup at boot

[Service]
ExecStart=/home/$userexecuting/test.sh

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/VM-Autostart.service > /dev/null 2>&1


#TODO aggiungere controlli per verificare che le installazioni sono avvenute con successo


if [[ $autostartmode = true ]]; then
	sudo systemctl daemon-reload
	sudo systemctl start VM-startup.service
	sudo systemctl status VM-startup.service
else
	echo "Autostart is disabled."
	echo "You can always turn it on by using 'systemctl enable VM-Autostart.service' and restart."
fi









#TODO
exit 0

#Setup all the requirements packages. Discard the output of the update
sudo apt update > /dev/null 2>&1
sudo apt install qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf
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
exit 0