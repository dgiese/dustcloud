#!/bin/bash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#
# Intended to work on s5e,p5,a08,a11
#
DEVICEMODEL="CHANGEDEVICEMODELCHANGE"

echo "---------------------------------------------------------------------------"
echo " Roborock manual Firmware installer"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Intended to work on s5e, p5, a08, a11"
echo " Version: ${DEVICEMODEL}"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

grep -xq "^model=${DEVICEMODEL}$" /mnt/default/device.conf
if [ $? -eq 1 ]; then
	echo "(!!!) It seems you are trying to run the installer on a $(sed -rn 's/model=(.*)/\1/p' /mnt/default/device.conf) instead of ${DEVICEMODEL}."
	exit 1
fi

if grep -q "boot_fs=a" /proc/cmdline; then
		echo "We are currently on rootfs1, will installing on rootfs2"
		BOOT_PART=/dev/nandd
		ROOT_FS_PART=/dev/nandf
elif grep -q "boot_fs=b" /proc/cmdline; then
		echo "We are currently on rootfs2, will installing on rootfs1"
		BOOT_PART=/dev/nandc
		ROOT_FS_PART=/dev/nande
else
		echo "(!!!) unsupported boot configuration!"
		exit 1
fi

echo "check image file size"
maximumsize=26000000
minimumsize=20000000
# maxsizeplaceholder
# minsizeplaceholder
actualsize=$(wc -c < /mnt/data/rootfs.img)
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash. Aborting the installation"
	exit 1
fi
if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation. Aborting the installation"
	exit 1
fi

if [[ -f /mnt/data/boot.img ]]; then
	if [[ -f /mnt/data/rootfs.img ]]; then
		echo "Checking integrity"
		md5sum -c firmware.md5sum
		if [ $? -ne 0 ]; then
			echo "(!!!) integrity check failed. Firmware files are damaged. Please re-download the firmware. Aborting the installation"
			exit 1
		fi
		echo "Start installation ..."
		echo "Installing Kernel"
		dd if=/mnt/data/boot.img of=${BOOT_PART} bs=8192
		echo "Installing OS"
		dd if=/mnt/data/rootfs.img of=${ROOT_FS_PART} bs=8192

		echo "Trying to mount system"
		mkdir /tmp/system
		mount ${ROOT_FS_PART} /tmp/system
		if [ ! -f /tmp/system/build.txt ]; then
			echo "(!!!) Did not found marker in updated firmware. Update likely failed, wont update system_a."
			exit 1
		fi

		if grep -q "boot_fs=a" /proc/cmdline; then
			echo "Setting next boot to B"
			echo -n -e '\xf1' | dd of=/dev/nanda bs=1 seek=323840
		elif grep -q "boot_fs=b" /proc/cmdline; then
			echo "Setting next boot to A"
			echo -n -e '\xf0' | dd of=/dev/nanda bs=1 seek=323840
		fi

		echo "----------------------------------------------------------------------------------"
		echo "Done, please reboot and check if the robot boots the new firmware"
		echo "Repeat installion after rebooting, if everything works"
		echo "Dont forget to delete the installer files after rebooting"
		echo "----------------------------------------------------------------------------------"
	else
		echo "(!!!) rootfs.img not found in /mnt/data"
	fi
else
	echo "(!!!) boot.img not found in /mnt/data"
fi
