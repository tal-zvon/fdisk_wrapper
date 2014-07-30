fdisk_wrapper
=============

fdisk_wrapper is a wrapper for fdisk. It lets you have 'fdisk -l' ignore any
disks you want it to

Requirements:

	fdisk and lsblk
	Other than that, the scripts should pretty much be universal
	They were tested on CentOS 7 and Debian 7, but are highly portable (in theory)

Install:

	Run install.sh as root

Uninstall:

	Delete /usr/local/bin/fdisk
