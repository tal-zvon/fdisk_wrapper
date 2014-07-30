#!/bin/bash
FDISK_PATH=''
DEVICES_TO_SKIP=''
SCRIPT_DIR=$(dirname $(readlink -f $0))

trap 'echo; exit 1' SIGINT

#Only run if user is root
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "You must be root to run $0. Try again with the command 'sudo $0'" | fmt -w `tput cols`; exit 1; }

#Check if wrapper script is already installed
[[ -e /usr/local/bin/fdisk ]] &&
{ echo 'the fdisk wrapper script is already installed'; exit 1; }

#Check if fdisk is in current directory
[[ -e $SCRIPT_DIR/fdisk ]] ||
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
read -e DEVICES_TO_SKIP

#Remove commas in the input
DEVICES_TO_SKIP=$(echo $DEVICES_TO_SKIP | sed 's/,//g')

#Check for invalid input

ERROR=false

for DEVICE in $DEVICES_TO_SKIP
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

#Copy fdisk to /usr/local/bin/
echo
cp -v $SCRIPT_DIR/fdisk /usr/local/bin/ &&
chown -v root:root /usr/local/bin/fdisk &&
chmod -v 755 /usr/local/bin/fdisk ||
{ echo "Failed to install fdisk to /usr/local/bin/"; [[ -e /usr/local/bin/fdisk ]] && rm -f /usr/local/bin/fdisk exit 1; }

#Modify fdisk's FDISK_PATH
sed -i "s#^FDISK_PATH.*#FDISK_PATH=$FDISK_PATH#g" /usr/local/bin/fdisk ||
echo "Failed to set FDISK_PATH variable on /usr/local/bin/fdisk"

#Modify fdisk's DEVICES_TO_SKIP
sed -i "s#^DEVICES_TO_SKIP.*#DEVICES_TO_SKIP='$DEVICES_TO_SKIP'#g" /usr/local/bin/fdisk ||
echo "Failed to set DEVICES_TO_SKIP variable on /usr/local/bin/fdisk"

#Check if sudo is going to be a problem
sudo bash -c 'echo $PATH' | grep -q '/usr/local/bin' ||
{
	echo "WARNING: /usr/local/bin is NOT in your sudo's \$PATH"
	echo -e "\tThis is only bad if you plan to run fdisk using sudo"
	echo -e "\tSee secure_path of /etc/sudoers to set sudo's \$PATH"
	echo -e "\t/usr/local/bin must be added ahead of $(dirname $FDISK_PATH)"
}

#Write that everything is done successfully
echo "fdisk installed successfully"
