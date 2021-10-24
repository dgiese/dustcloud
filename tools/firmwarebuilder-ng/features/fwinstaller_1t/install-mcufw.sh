#!/bin/ash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#
# Intended to work on dreame devices
#

if [[ -f /mcu.bin ]]; then
	mkdir -p /tmp/update
	cp /mcu.bin /tmp/update
	echo 1 > /tmp/update/only_update_mcu_mark
	avacmd ota  '{"type": "ota", "cmd": "report_upgrade_status", "status": "AVA_UNPACK_OK", "result": "ok"}'
else
	echo "(!!!) mcu.bin not found"
fi