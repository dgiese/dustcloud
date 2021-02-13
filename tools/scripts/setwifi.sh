#!/bin/bash

echo ssid=\"MySSID\" > /mnt/data/miio/wifi.conf
echo psk=\"MyPassword\" >> /mnt/data/miio/wifi.conf
echo key_mgmt=\"WPA\" >> /mnt/data/miio/wifi.conf
echo uid=0 >> /mnt/data/miio/wifi.conf
echo region=us >> /mnt/data/miio/wifi.conf
echo cfg_by=miot >> /mnt/data/miio/wifi.conf
echo 0 > /mnt/data/miio/device.uid
echo "us" > /mnt/data/miio/device.country