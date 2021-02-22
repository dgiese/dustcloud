#!/bin/bash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
# 
# Intended to work on v1,s4,s5,s6,t4,t6
#
# This tool installs the partition image on System_A and patches the root password
# System_B is marked then as GOOD in order to force the next boot from System_A
# It needs to be executed with System_B being active
# This script is intended to be execute in the second step, after install_b has been executed
DEVICEMODEL="CHANGEDEVICEMODELCHANGE"

echo "---------------------------------------------------------------------------"
echo " Xiaomi/Roborock/Rockrobo manual Firmware installer Stage 2"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Intended to work on v1, s4, s5, s6, t4, t6"
echo " Version: ${DEVICEMODEL}"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

grep -xq "^model=${DEVICEMODEL}$" /mnt/default/device.conf
if [ $? -eq 1 ]; then
	echo "(!!!) It seems you are trying to run the installer on a $(sed -rn 's/model=(.*)/\1/p' /mnt/default/device.conf) instead of ${DEVICEMODEL}."
	exit 1
fi

grep -q "boot_fs=b" /proc/cmdline
if [ $? -eq 1 ]; then
	echo "(!!!) You did not boot into System_B. This installer should be only executed after you run install_b.sh first!"
	exit 1
fi

md5sum -c firmware.md5sum
if [ $? -ne 0 ]; then
	echo "(!!!) integrity check failed. Firmware files are damaged. Please re-download the firmware. Aborting the installation"
	exit 1
fi 

if [[ -f /mnt/data/disk.img ]]; then
	echo "Installing(this make take a few minutes) ..."
	dd if=/mnt/data/disk.img of=/dev/mmcblk0p8
	echo "marking System_A as GOOD"
	echo -n -e '\x1' | dd conv=notrunc of="/dev/mmcblk0p5" bs=1 count=1 seek=309504
	mkdir /mnt/a
	mount /dev/mmcblk0p8 /mnt/a
	cp /etc/shadow /mnt/a/etc/shadow
	umount /mnt/a
	sync
	echo "Deleting disk.img"
	rm /mnt/data/disk.img
	echo "----------------------------------------------------------------------------------"
	echo "Now is a good moment to delete the installation file (disk.img and tar.gz)"
	echo "Please reboot the robot, the firmware update process should be now finished ;)"
	echo "----------------------------------------------------------------------------------"
else
	echo "(!!!) disk.img not found in /mnt/data"
fi
