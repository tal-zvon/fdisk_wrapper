#!/bin/bash
FDISK_PATH=''
DEVICES_TO_SKIP=''
SCRIPT_DIR=$(dirname $(readlink -f $0))

#Controls whether the fdisk wrapper sript tries to immitate fdisk's output
#or be smarter
IMITATE_FDISK=false

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

FDISK_PATH=$(which fdisk)

get_list_of_devices(){
        for DEVICE in $(cat /proc/partitions  | tail -n+3 | tr -s ' ' | cut -d ' ' -f 5)
        do
                #If /dev/$DEVICE is a block device, add /dev prefix to it
                #If it doesn't exist, skip it
                [[ -b /dev/$DEVICE ]] && DEVICE=/dev/$DEVICE || continue

                #Ignore partitions
                if echo $DEVICE | grep -q '^/dev/sd[a-z][0-9][0-9]*'
                then
                        continue
                fi

                #Ignore CDs/DVDs
                if echo $DEVICE | grep -q '^/dev/sr'
                then
                        continue
                fi

                #Should we try to act like fdisk when it's something dumb, or try to
                #do better?
                if $IMITATE_FDISK
                then
                        #Do what fdisk does - ignore loop devices directly under /dev
                        if echo $DEVICE | grep -q '^/dev/loop'
                        then
                                continue
                        fi
                else
                        #Check if the loop device looks like it has a partition table
                        if ! $FDISK_PATH -l $DEVICE 2>/dev/null | grep -q Start
                        then
                                continue
                        fi
                fi

                #If $DEVICE has a mapping under /dev/mapper (as determined by 'dmsetup'),
                #use that instead of the regular /dev/ device
                #Real fdisk does this too
                #Note: We don't explicitly check for existence of 'dmsetup' on the system
                #       because if it doesn't, the command below will quietly fail anyway,
                #       and we only care if it succeeds
                if dmsetup info $DEVICE &>/dev/null
                then
                        DEVICE=/dev/mapper/$(dmsetup info $DEVICE | grep Name | tr -s ' ' | cut -d ' ' -f 2)
                fi

                #If $DEVICE is a PARTITION on a loop device, ignore it.
                #Real fdisk doesn't do this check
                $IMITATE_FDISK ||
                if echo $DEVICE | grep -q '^/dev/mapper/loop[0-9]'
                then
                        continue
                fi

                #If $DEVICE is a logical volume, ignore it. It's basically like running
                #fdisk on a partition
                #Real fdisk doesn't do this check
                #Note: We don't explicitly check for existence of 'lvdisplay' on the system
                #       because if it doesn't, the command below will quietly fail anyway,
                #       and we only care if it succeeds
                $IMITATE_FDISK ||
                if lvdisplay "$DEVICE" &>/dev/null
                then
                        continue
                fi

                #If $DEVICE ends in #p#, it's a partition, so ignore it.
                #Real fdisk doesn't do this check
                $IMITATE_FDISK ||
                if echo $DEVICE | grep -q '[0-9]p[0-9][0-9]*'
                then
                        continue
                fi

                #/sbin/fdisk -l $DEVICE
                echo $DEVICE
        done
}

clear
echo "There are several cases where fdisk runs against partitions, rather than disks, which shows mostly useless output and clutters up your terminal. This script adds some additional checks to make sure that this does NOT happen. The result is that this script's output may be slightly different than real fdisk's output. Do you want the script to ignore these additional checks and act exactly like fdisk, even when fdisk is doing something dumb?" | fmt -w `tput cols`
echo
echo "Hint: Only say 'yes' if you understand the question, and have a good reason to do this" | fmt -w `tput cols`
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
echo "Which devices would you like fdisk to ignore when you run "fdisk -l"? (eg: '/dev/sda, /dev/sdf')" | fmt -w `tput cols`
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
{ echo "Failed to install fdisk to /usr/local/bin/"; [[ -e /usr/local/bin/fdisk ]] && rm -f /usr/local/bin/fdisk exit 1; }

#Modify fdisk's FDISK_PATH
sed -i "s#^FDISK_PATH.*#FDISK_PATH=$FDISK_PATH#g" /usr/local/bin/fdisk ||
echo "Failed to set FDISK_PATH variable on /usr/local/bin/fdisk"

#Modify fdisk's DEVICES_TO_SKIP
sed -i "s#^DEVICES_TO_SKIP.*#DEVICES_TO_SKIP='$DEVICES_TO_SKIP'#g" /usr/local/bin/fdisk ||
echo "Failed to set DEVICES_TO_SKIP variable on /usr/local/bin/fdisk"

#Modify fdisk's IMITATE_FDISK (only if it's 'true', since 'false' is the default)
$IMITATE_FDISK &&
sed -i "s#^IMITATE_FDISK.*#IMITATE_FDISK=true#g" /usr/local/bin/fdisk ||
echo "Failed to set IMITATE_FDISK variable on /usr/local/bin/fdisk"

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
