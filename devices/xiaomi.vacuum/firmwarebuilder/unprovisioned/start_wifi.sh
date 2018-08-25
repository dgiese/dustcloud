#!/bin/bash

file="/opt/unprovisioned/wpa_supplicant.conf"
if [ ! -f "$file" ]
then
    echo "$0: File '${file}' not found."
else
    #add enough time to fix wrong wireless settings
    sleep 200

    #disable accesspoint
    ifdown wlan0 > /dev/null 2>&1
    ifconfig wlan0 down > /dev/null 2>&1
    killall hostapd >/dev/null 2>&1
    iw mon.wlan0 del >/dev/null 2>&1
    create_ap --stop wlan0 > /dev/null 2>&1
    killall wpa_supplicant >/dev/null 2>&1
    killall dhclient >/dev/null 2>&1

    #login to your network
    ifconfig wlan0 up >/dev/null 2>&1
    /sbin/wpa_supplicant -s -B -P /var/run/wpa_supplicant_1.wlan0.pid -i wlan0 -D nl80211,wext -c /mnt/data/unprovisioned/wpa_supplicant.conf -C /var/run/wpa_supplicant >/dev/null 2>&1
    dhclient wlan0 >/dev/null 2>&1
fi
