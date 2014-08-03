#!/bin/bash
FDISK_PATH=$(which fdisk)
DEVICES_TO_SKIP=''
SCRIPT_DIR=$(dirname $(readlink -f $0))

#Controls whether the fdisk wrapper script tries to immitate fdisk's output
#or be smarter
IMITATE_FDISK=false

#If user hits Ctrl+C, write a new line before
#exiting, or else it just looks weird
trap 'echo; exit 1' SIGINT

#Only run if user is root
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "You must be root to run $0."; echo "Try again with the command 'sudo $0'"; exit 1; }

#Check if wrapper script is already installed
[[ -e /usr/local/bin/fdisk ]] &&
{ echo 'the fdisk wrapper script is already installed'; exit 1; }

#Check if fdisk is in current directory
[[ -e $SCRIPT_DIR/fdisk ]] ||
{ echo "'fdisk' not found in current directory"; exit 1; }

#Check if the LIB library is available in the same dir
#as this install.sh script
[[ -e $SCRIPT_DIR/LIB ]] && . $SCRIPT_DIR/LIB ||
{ echo "LIB library not found"; exit 1; }

#Check if /usr/local/bin exists
[[ -d /usr/local/bin/ ]] || mkdir /usr/local/bin/ ||
{ echo "Failed to create /usr/local/bin/"; exit 1; }

clear
echo "There are several cases where fdisk runs against partitions, rather than disks,
which shows mostly useless output and clutters up your terminal. This script
adds some additional checks to make sure that this does NOT happen. The result
is that this script's output may be slightly different than real fdisk's
output. Do you want the script to ignore these additional checks and act
exactly like fdisk, even when fdisk is doing something dumb?"
echo
echo "Hint: Only say 'yes' if you understand the question, and have a good
reason to do this"
echo -n "Your answer [y/N]: "
read answer

#Convert answer to lowercase
lanswer=$(echo $answer | tr "[:upper:]" "[:lower:]")

#Default to no if variable is empty
if [ ! -n "$lanswer" ]
then
	lanswer=n
fi

case "$lanswer" in
	y|yes)
		echo "fdisk imitation mode enabled"
		IMITATE_FDISK=true
		;;
	n|no)
		echo "fdisk imitation mode disabled"
		IMITATE_FDISK=false
		;;
	*)
		echo "'$answer' is not a valid answer"
		echo "fdisk wrapper installation aborted"
		exit 1
		;;
esac

clear
echo -e "Available devices: \n"
for DEVICE in $(get_list_of_devices)
do
	echo $DEVICE
done
echo
echo "Which devices would you like fdisk to ignore when you run 'fdisk -l'?"
echo "(eg: '/dev/sda, /dev/sdf')"
echo -n "Your answer: "
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

	DEV_FOUND=false
	#Check if device is in the list of devices we are going to run fdisk against
	for AVAIL_DEV in $(get_list_of_devices)
	do
		if [[ "$DEVICE" == "$AVAIL_DEV" ]]
		then
			DEV_FOUND=true
		fi
	done

	$DEV_FOUND ||
	{ echo "'$DEVICE' is not one of the available devices"; ERROR=true; continue; }
done

#If there were errors, exit
$ERROR && exit 1

#########################
#########INSTALL#########
#########################

#Copy fdisk to /usr/local/bin/
echo
cp -v $SCRIPT_DIR/fdisk /usr/local/bin/ &&
chown -v root:root /usr/local/bin/fdisk &&
chmod -v 755 /usr/local/bin/fdisk ||
{ echo "Failed to install fdisk to /usr/local/bin/"; [[ -e /usr/local/bin/fdisk ]] && rm -f /usr/local/bin/fdisk; exit 1; }

#Modify fdisk's FDISK_PATH
sed -i "s#^FDISK_PATH.*#FDISK_PATH=$FDISK_PATH#g" /usr/local/bin/fdisk ||
echo "Failed to set FDISK_PATH variable on /usr/local/bin/fdisk"

#Modify fdisk's DEVICES_TO_SKIP
sed -i "s#^DEVICES_TO_SKIP.*#DEVICES_TO_SKIP='$DEVICES_TO_SKIP'#g" /usr/local/bin/fdisk ||
echo "Failed to set DEVICES_TO_SKIP variable on /usr/local/bin/fdisk"

#Modify fdisk's IMITATE_FDISK (only if it's 'true', since 'false' is the default)
$IMITATE_FDISK &&
{
	sed -i "s#^IMITATE_FDISK.*#IMITATE_FDISK=true#g" /usr/local/bin/fdisk ||
	echo "Failed to set IMITATE_FDISK variable on /usr/local/bin/fdisk"
}

#Copy LIB library into /usr/local/bin/fdisk
sed -i "/^LIBRARY_HERE/{r$SCRIPT_DIR/LIB
d
}" /usr/local/bin/fdisk ||
{ echo "Failed to replace LIBRARY_HERE with LIB library"; [[ -e /usr/local/bin/fdisk ]] && rm -f /usr/local/bin/fdisk; exit 1; }

#Check if sudo is on the system
if which sudo &>/dev/null
then
	#Check if sudo's $PATH contains /usr/local/bin
	sudo bash -c 'echo $PATH' | grep -q '/usr/local/bin' ||
	{
		echo "WARNING: /usr/local/bin is NOT in your sudo's \$PATH"
		echo -e "\tThis is bad if you plan to run fdisk using sudo"
		echo -e "\tSee secure_path of /etc/sudoers to set sudo's \$PATH"
		echo -e "\t/usr/local/bin must be added ahead of $(dirname $FDISK_PATH)"
	}

	#Check if root's $PATH contains /usr/local/bin
	su - -c 'echo $PATH' | grep -q '/usr/local/bin' ||
	{
		echo "WARNING: /usr/local/bin is NOT in your root's \$PATH"
		echo -e "\tThis is bad if you plan to run fdisk directly as root (without sudo)"
		echo -e "\t/usr/local/bin must be added ahead of $(dirname $FDISK_PATH)"
	}
else
	#Check if root's $PATH contains /usr/local/bin
	echo $PATH | grep -q '/usr/local/bin' ||
	{
		echo "WARNING: /usr/local/bin is NOT in your root's \$PATH"
		echo -e "\tThis is bad if you plan to run fdisk directly as root (without sudo)"
		echo -e "\t/usr/local/bin must be added ahead of $(dirname $FDISK_PATH)"
	}
fi

#Write that everything is done successfully
echo "fdisk installed successfully"
