#!/bin/bash

FDISK_PATH=/sbin/fdisk

#There are several cases where fdisk runs against partitions, rather than
#disks. This script makes sure that this does NOT happen. The result is that
#this script's output may be slightly different than real fdisk's output. If you
#want the output to be exactly the same, set IMITATE_FDISK to true to disable
#these extra checks
IMITATE_FDISK=false

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
	#	because if it doesn't, the command below will quietly fail anyway,
	#	and we only care if it succeeds
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
	#	because if it doesn't, the command below will quietly fail anyway,
	#	and we only care if it succeeds
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
