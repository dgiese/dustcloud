#!/bin/bash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
# 
# Intended to work on v1,s4,s5,s6,t4,t6
#
# This tool installs the partition image on System_B and patches the root password
# System_A is marked then as BAD in order to force the next boot from System_B
# It needs to be executed with System_A being active
DEVICEMODEL="CHANGEDEVICEMODELCHANGE"

echo "---------------------------------------------------------------------------"
echo " Xiaomi/Roborock/Rockrobo manual Firmware installer Stage 1"
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

grep -q "boot_fs=a" /proc/cmdline
if [ $? -eq 1 ]; then
	echo "(!!!) You did not boot into System_A. It is not safe to execute this script"
	exit 1
fi

md5sum -c firmware.md5sum
if [ $? -ne 0 ]; then
	echo "(!!!) integrity check failed. Firmware files are damaged. Please re-download the firmware. Aborting the installation"
	exit 1
fi 

if [[ -f /sbin/cleanflags.sh ]]; then
	echo "detected resetfix, disabling it"
	echo "#!/bin/bash" > /sbin/cleanflags.sh
	echo "exit 0" >> /sbin/cleanflags.sh
fi

if [[ -f /mnt/data/disk.img ]]; then
	echo "Installing(this make take a few minutes) ..."
	dd if=/mnt/data/disk.img of=/dev/mmcblk0p9
	echo "marking System_B as GOOD"
	echo -n -e '\x1' | dd conv=notrunc of="/dev/mmcblk0p5" bs=1 count=1 seek=311552
	echo "marking System_A as BAD (this is expected)"
	echo -n -e '\x4' | dd conv=notrunc of="/dev/mmcblk0p5" bs=1 count=1 seek=309504
	mkdir /mnt/a
	mount /dev/mmcblk0p9 /mnt/a
	cp /etc/shadow /mnt/a/etc/shadow
	umount /mnt/a
	sync
	echo "---------------------------------------------------------------------------"
	echo "Please reboot the robot, login again and execute install_a.sh in /mnt/data"
	echo "---------------------------------------------------------------------------"
else
	echo "(!!!) disk.img not found in /mnt/data"
fi
