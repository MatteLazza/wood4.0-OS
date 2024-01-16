# wood4.0-OS

This repository contains all the bash scripts that can be used to handle all aspects of virtual machines.

### Workflow

1) Platform_Install.sh : This script is used to setup all the basic requirements for KVM and libvirt. It require sudo permissions for installing packages;
2) Start_Machine.sh : This script is used to run the virtual machine. Using different flags, it's possible to open the VM interface with different mechanisms;

- Versioner.sh : This script is used to handle all steps related to snapshots and revert;
- VMcreate.sh : This script is used to create new virtual machines, starting from an existing virtual disk. It's possible to configure multiple aspects of the machine.

All scripts contain 2 basic flags:
- -h : This flag is used to show the syntax of the script;
- -l : This flag is used to return all the informations about the flags available for the script.
