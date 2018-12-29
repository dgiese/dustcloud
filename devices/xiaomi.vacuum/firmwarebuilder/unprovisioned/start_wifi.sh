#!/bin/bash

config="/opt/unprovisioned/wpa_supplicant.conf"
log="/opt/unprovisioned/wpa_supplicant.log"

if [ ! -r "$config" ]
then
    echo "$0: File '${config}' not found." > "$log"
else
    #add enough time to fix wrong wireless settings
    sleep 200

    #disable accesspoint
    echo "Stopping AP..." > "$log"
    create_ap --stop wlan0 >> "$log" 2>&1
    echo "Killing leftover AP daemons..." >> "$log"
    killall hostapd >> "$log" 2>&1

    #login to your network
    echo "Starting WPA supplicant background process..." >> "$log"
    /sbin/wpa_supplicant -B -iwlan0 -Dnl80211 -c"$config" >> "$log" 2>&1
    echo "Requesting IP and network settings from DHCP server..." >> "$log"
    dhclient wlan0 >> "$log" 2>&1
fi
