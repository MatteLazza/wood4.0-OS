# wood4.0-OS

This repository contains all the bash scripts that can be used to handle all aspects of virtual machines.
The system works by using an already existing pre-configured virtual disk.

### Workflow

1) Platform_Install.sh : Script used to setup all the basic requirements for KVM and libvirt. It require sudo permissions for installing packages; It's possible to set up all the parameters that will be used for creating the virtual machine.
2) VMcreate.sh: Script used to create the virtual machine. It's possible to specify all the informations of the virtual machine.
3) Start_Machine.sh: Script used to start the specified virtual machine. It's possible to use different configurations to specify the behavior of the interface.
4) Versioner.sh: Script used to handle all the aspects of the snapshots.
5) usb_detect.sh: Script used to handle the add/remove of USBs in the host. This will configure the machine at runtime to make sure those USBs are seen from the guest.
6) Expand_Disk.sh: Script used to increase the size of the disk, keeping everything inside.

Most of the scripts automatically call other scripts to automate the full process of startup/creation.

- Once all requirements for KVM and libvirt has been installed, Platform_Install.sh procede to execute the VMcreate.sh to create the virtual machine and finish the setup (it's possible to not do this using a specific flag).
- When the machine start execution, Start_Machine.sh automatically start usb_detect.sh for passing the USBs from the host to the guest.

### Help and listing

All scripts have -h and, in some cases, -l.
Those commands are used to view the correct syntax of the command and list all the possible arguments used in the script.

### Testing

For validating scripts execution, some scripts has been developed to test functionalities. Scripts test as much cases as possible, seeing all possible cases.
For Platform_Install.sh, because it require testing installations and verify activation of services, a new ubuntu virtual machine has been created and used to verify the code.