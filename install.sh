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

#Check for invalid input

ERROR=false

INVALID_INPUT=$(echo $DEVICES | tr ' ' '\n' | grep -v '^/dev/' | tr '\n' ' ' | sed 's/ $//g')
if [[ -n $INVALID_INPUT ]]
then
	if [[ $(echo $INVALID_INPUT | grep -o ' ' | wc -c) -eq 0 ]]
	then
		echo "'$INVALID_INPUT' does not exist"
		ERROR=true
	else
		echo "'$INVALID_INPUT' do not exist"
		ERROR=true
	fi
fi

DEVICES=$(echo $DEVICES | grep -o '/dev/[-_a-Z0-9/]*')

for DEVICE in $DEVICES
do
	#Check if device is a valid block device
	[[ -b $DEVICE ]] || 
	{ echo "'$DEVICE' is not a valid block device"; ERROR=true; }
done

#If there were errors, exit
$ERROR && exit 1

echo stuff
