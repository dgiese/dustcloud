#!/bin/ash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#
# Intended to work on mc1808,p2008,p2009,p2041
#
DEVICEMODEL="CHANGEDEVICEMODELCHANGE"

echo "---------------------------------------------------------------------------"
echo " Dreame manual Firmware installer"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Intended to work on mc1808,p2008,p2009,p2041"
echo " Version: ${DEVICEMODEL}"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

grep "model=${DEVICEMODEL}" /data/config/miio/device.conf
if [ $? -eq 1 ]; then
	echo "(!!!) It seems you are trying to run the installer on a $(sed -rn 's/model=(.*)/\1/p' /tmp/config/miio/device.conf) instead of ${DEVICEMODEL}."
	exit 1
fi

echo "check image file size"
maximumsize=26000000
minimumsize=20000000
# maxsizeplaceholder
# minsizeplaceholder
actualsize=$(wc -c < ./rootfs.img)
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks too big. The size might exceed the available space on the flash. Aborting the installation"
	exit 1
fi
if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks too small. Maybe something went wrong with the image generation. Aborting the installation"
	exit 1
fi

if [[ -f ./boot.img ]]; then
	if [[ -f ./rootfs.img ]]; then
		echo "Checking integrity"
		md5sum -c firmware.md5sum
		if [ $? -ne 0 ]; then
			echo "(!!!) integrity check failed. Firmware files are damaged. Please re-download the firmware. Aborting the installation"
			exit 1
		fi

		#set -x
		source /usr/bin/config

		echo "Starting installation ..."

		BOOT_MODE=$(fw_printenv boot_partition)

		echo "${BOOT_MODE}" | grep boot1

		if [ $? -eq 0 ]
		then
				echo "We are currently on rootfs1, will install on rootfs2"
				BOOT_PART=/dev/by-name/boot2
				ROOT_FS_PART=/dev/by-name/rootfs2
				BOOT_PARTITION=boot2
				ROOT_PARTITION=rootfs2
		else
				echo "We are currently on rootfs2, will install on rootfs1"
				BOOT_PART=/dev/by-name/boot1
				ROOT_FS_PART=/dev/by-name/rootfs1
				BOOT_PARTITION=boot1
				ROOT_PARTITION=rootfs1
		fi
		echo "Installing Kernel"
		dd if=./boot.img of=${BOOT_PART} bs=8192
		echo "Installing OS"
		dd if=./rootfs.img of=${ROOT_FS_PART} bs=8192

		if [ $? -eq 0 ]
		then
				echo "Trying to mount system"
				mount ${ROOT_FS_PART} /mnt
				if [ $? -ne 0 ]; then
					sync
					echo "(!!!) Mount failed. Update likely failed, wont change the boot order"
					exit 1
				fi

				if [ -f /mnt/build.txt ]; then
						fw_setenv boot_partition ${BOOT_PARTITION}
						fw_setenv root_partition ${ROOT_PARTITION}
						echo "----------------------------------------------------------------------------------"
						echo "Done, rebooting"
						echo "Dont forget to delete the installer files after rebooting"
						echo "----------------------------------------------------------------------------------"
						sync
						reboot -n -f
				else
				  sync
				  echo "(!!!) Did not find marker in updated firmware. Update likely failed, wont change the boot order"
				  exit 1
				fi
		else
			sync
			echo "(!!!) DD returned an error. Update likely failed, wont change the boot order"
			exit 1
		fi
	else
		echo "(!!!) rootfs.img not found"
	fi
else
	echo "(!!!) boot.img not found"
fi
