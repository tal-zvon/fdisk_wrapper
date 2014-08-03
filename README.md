fdisk_wrapper
=============

fdisk_wrapper is a wrapper for fdisk. It lets you have 'fdisk -l' ignore any
disks you want it to

Requirements:

	bash and fdisk
	Other than that, the scripts should pretty much be universal, and use nothing that
		even the most minimalistic embeded linux systems should have problems with
	Both scripts were tested on CentOS 7, Debian 7, and Alpine but are highly portable
		(in theory) and should work on most distros that fdisk works on

Install:

	Run install.sh as root

Uninstall:

	Delete /usr/local/bin/fdisk

Configure After Installation:

	If you want to change the devices that the wrapper script ignores without
		reinstalling it, just edit /usr/local/bin/fdisk directly, and add
		the devices to the DEVICES_TO_SKIP='' line (near the top of the file)
