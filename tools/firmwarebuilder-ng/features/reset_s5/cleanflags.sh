#!/bin/bash

# needs to be bash or echo gets sad and writed wrong data (0x2d instead of 0x01)
# example integration in https://dustbuilder.xvm.mit.edu/resetfix_maybe/

# shellcheck disable=SC2034
_DEV="/dev/mmcblk0p5"
_LOG_FILE="/mnt/reserve/factory_reset_detection.log"
# 0x1 ... just for reference
_SHALL="AQ=="
# 0x4 ... thats bad, this is not reached under normal circumstances (updates: 0x1-0x3)
_SHALLNOT="BA=="
_RESET_DETECTED=0

actual=$(/bin/dd if="/dev/mmcblk0p5" bs=1 count=1 skip=309504 | /usr/bin/base64)
if [ "$_SHALLNOT" == "$actual" ] ; then
	  date >> "$_LOG_FILE"
		echo -n " 309504" >> "$_LOG_FILE"
		echo -n "$_SHALL" >> "$_LOG_FILE"
		echo -n " " >> "$_LOG_FILE"
		echo -n "$actual" >> "$_LOG_FILE"
		echo -n " " >> "$_LOG_FILE"
		echo " - bad partition flag detected for systemA" >> "$_LOG_FILE"
        _RESET_DETECTED=1
fi

actual=$(/bin/dd if="/dev/mmcblk0p5" bs=1 count=1 skip=311552 | /usr/bin/base64)
if [ "$_SHALLNOT" == "$actual" ] ; then
	  date >> "$_LOG_FILE"
		echo -n " 311552" >> "$_LOG_FILE"
		echo -n $_SHALL >> "$_LOG_FILE"
		echo -n " " >> "$_LOG_FILE"
		echo -n "$actual" >> "$_LOG_FILE"
		echo -n " " >> "$_LOG_FILE"
		echo " - bad partition flag detected for systemB" >> "$_LOG_FILE"
        _RESET_DETECTED=1
fi

# Clean flags only if they have a bad flag. This prevents the sysupdate process from being sad
if [ $_RESET_DETECTED -ne 0 ] ; then
    echo -n -e '\x1' | /bin/dd conv=notrunc of="/dev/mmcblk0p5" bs=1 count=1 seek=309504
    echo -n -e '\x1' | /bin/dd conv=notrunc of="/dev/mmcblk0p5" bs=1 count=1 seek=311552
    date >> "$_LOG_FILE"
    echo " flags cleaned" >> "$_LOG_FILE"
fi
