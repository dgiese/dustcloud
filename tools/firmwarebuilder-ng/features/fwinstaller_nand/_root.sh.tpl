#!/bin/bash
if [[ -f /mnt/data/valetudo ]]; then
	mkdir -p /mnt/data/miio/
	
	if grep -q "cfg_by=tuya" /mnt/data/miio/wifi.conf; then
		sed -i "s/cfg_by=tuya/cfg_by=miot/g" /mnt/data/miio/wifi.conf
		sed -i "s/cfg_by=rriot/cfg_by=miot/g" /mnt/data/miio/wifi.conf
		echo region=de >> /mnt/data/miio/wifi.conf
		echo 0 > /mnt/data/miio/device.uid
		echo "de" > /mnt/data/miio/device.country
	fi

	VALETUDO_CONFIG_PATH=/mnt/data/valetudo_config.json /mnt/data/valetudo >> /dev/null 2>&1 &
fi

### It is strongly recommended that you put your changes inside the IF-statement above. In case your changes cause a problem, a factory reset will clean the data partition and disable your chances.
### Keep in mind that your robot model does not have a recovery partition. A bad script can brick your device!

