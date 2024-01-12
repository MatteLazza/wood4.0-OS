#!/bin/bash
# check whether user had supplied -h or --help . If yes display usage
if [[ $@ == "--help" ||  $@ == "-h" ]]
then 
	echo "Usage: ./Platform_Install.sh"
	echo "Check ./Platform_Install.sh -l for the packages that will be installed"
	exit 0
fi 
# check whether user had supplied -l or --list . If yes display list of arguments
if [[ $@ == "--list" ||  $@ == "-l" ]]
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

echo 'deb http://us.archive.ubuntu.com/ubuntu jammy universe restricted' | sudo tee /etc/apt/sources.list -a >/dev/null 2>&1
echo 'deb-src http://us.archive.ubuntu.com/ubuntu jammy universe restricted' | sudo tee /etc/apt/sources.list -a >/dev/null 2>&1

#Setup all the requirements packages. Discard the output of the update
sudo apt update > /dev/null 2>&1
sudo apt install -qq qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf -y

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
