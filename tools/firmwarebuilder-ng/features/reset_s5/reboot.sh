#!/bin/sh

_DEV="/dev/mmcblk0p5"
_LOG_FILE="/mnt/data/factory_reset_detection.log"
_OFFSET_PARTITION_A=0x4b900
_OFFSET_PARTITION_B=0x4c100
_SHALL=$(echo -n -e '\x1' | base64)
_RESET_DETECTET=0

for offset in $_OFFSET_PARTITION_A $_OFFSET_PARTITION_B ; do
    actual=$(dd if="$_DEV" bs=1 count=1 skip=$((offset)) | \
                 base64)
    if [ "$_SHALL" != "$actual" ] ; then
        _RESET_DETECTET=1
        echo -n -e '\x1' | \
            dd conv=notrunc of="$_DEV" bs=1 count=1 seek=$((offset))
    fi
done

if [ $_RESET_DETECTET -ne 0 ] ; then
    date >> "$_LOG_FILE"
    echo " - Attempted factory reset detected and prevented" >> "$_LOG_FILE"
fi

/sbin/reboot_
