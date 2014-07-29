#!/bin/bash
FDISK_PATH=''
DEVICES_TO_SKIP=''

trap 'echo; exit 1' SIGINT

#Only run if user is root
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "You must be root to run $0. Try again with the command 'sudo $0'" | fmt -w `tput cols`; exit 1; }

#Check if wrapper script is already installed
[[ -e /usr/local/bin/fdisk ]] &&
{ echo 'the fdisk wrapper script is already installed'; exit 1; }

#Check if fdisk is in current directory
[[ -e $(echo "$(dirname $(readlink -f $0))/fdisk") ]] ||
{ echo "'fdisk' not found in current directory"; exit 1; }

#Check if lsblk is installed
which lsblk &>/dev/null ||
{ echo 'lsblk is required, but was not detected.'; exit 1; }

FDISK_PATH=$(which fdisk)
#echo "\$FDISK_PATH=$FDISK_PATH"

clear
echo -e "Available devices: \n"
for DEVICE in $(lsblk -o KNAME,TYPE | grep 'disk$\|loop$\|dmraid$' | cut -d ' ' -f 1 | sort -u)
do
	echo /dev/$DEVICE
done
echo
echo -n "Which devices would you like fdisk to ignore when you run "fdisk -l"? (eg: /dev/sda, /dev/sdf): "
read -e DEVICES

#Remove commas in the input
DEVICES=$(echo $DEVICES | sed 's/,//g')

#Check for invalid input

ERROR=false

for DEVICE in $DEVICES
do
	#Check if the device file exists
	[[ -e $DEVICE ]] ||
	{ echo "'$DEVICE' does not exist"; ERROR=true; continue; }

	#Check if device is a valid block device
	[[ -b $DEVICE ]] || 
	{ echo "'$DEVICE' is not a valid block device"; ERROR=true; continue; }
done

#If there were errors, exit
$ERROR && exit 1

echo stuff
