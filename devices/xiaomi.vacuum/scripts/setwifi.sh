#!/bin/bash

echo ssid=\"MySSID\" > /mnt/data/miio/wifi.conf
echo psk=\"MyPassword\" >> /mnt/data/miio/wifi.conf
echo key_mgmt=\"WPA\" >> /mnt/data/miio/wifi.conf
echo uid=1234566790 >> /mnt/data/miio/wifi.conf
echo 1234566790 > /mnt/data/miio/device.uid
echo "" > /mnt/data/miio/device.country