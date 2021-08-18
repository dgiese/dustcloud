#!/bin/sh
echo 0 > /sys/module/8189fs/parameters/rtw_power_mgnt
echo 2 > /sys/module/8189fs/parameters/rtw_ips_mode
iw dev wlan0 set power_save off



if [ ! "$(readlink /data/config/system/localtime)" -ef "/usr/share/zoneinfo/UTC" ]; then
        rm /data/config/system/localtime
        ln -s /usr/share/zoneinfo/UTC /data/config/system/localtime
fi

if [[ -f /data/valetudo ]]; then
        VALETUDO_CONFIG_PATH=/data/valetudo_config.json /data/valetudo > /dev/null 2>&1 &
fi
