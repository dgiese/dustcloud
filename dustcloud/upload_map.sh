#!/bin/bash
# Author: Jens Schmer
# Copyright 2017 by Jens Schmer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# This script takes the device id, SLAM log and runtime map of the
# vacuum and sends it to the dustcloud server for processing.
DUSTCLOUD_SERVER=192.168.xx.yy
DUSTCLOUD_PORT=80

DEVICE_CONF=/mnt/data/miio/device.conf
SLAM_LOG=/var/run/shm/SLAM_fprintf.log
MAP_FILES=$(find /var/run/shm/ -iname '*.ppm')
set -- $MAP_FILES
MAP_FILE=$1

if [ ! -f $DEVICE_CONF ]; then
    echo "$DEVICE_CONF missing..."
    exit 0
fi
if [ ! -f $SLAM_LOG ]; then
    echo "$SLAM_LOG missing..."
    exit 0
fi
if [ -z "$MAP_FILE" ] || [ ! -f $MAP_FILE ]; then
    echo "Map file missing..."
    exit 0
fi

echo SLAM_LOG=$SLAM_LOG
echo MAP_FILE=$MAP_FILE

## Gather all data in a file

head -n1 $DEVICE_CONF > payload_tmp
printf "SLAM=%s\n" `stat --printf="%s" $SLAM_LOG` >> payload_tmp
cat $SLAM_LOG >> payload_tmp
printf "MAP=%s\n" `stat --printf="%s" $MAP_FILE` >> payload_tmp
cat $MAP_FILE >> payload_tmp

# Prepend magic and size to payload
FULL_SIZE=`stat --printf="%s" payload_tmp`
printf "ROCKROBO_MAP__\n%016d\n" $FULL_SIZE > payload
cat payload_tmp >> payload

## and send it to the dustcloud server
cat payload | nc -w 2 $DUSTCLOUD_SERVER $DUSTCLOUD_PORT
