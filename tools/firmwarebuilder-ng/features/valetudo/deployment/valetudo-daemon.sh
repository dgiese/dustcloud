#!/bin/sh
# from https://github.com/zvldz/vacuum/commits/master/custom-script/files/valetudo-daemon.sh
# created by:  zvldz aka vtel


mkdir -p /var/log/upstart

while :; do
    sleep 5
    if [ "$(cut -d"." -f1 /proc/uptime)" -lt 300 ]; then
        echo -n "Waiting for 20 sec after boot..."
        sleep 20
        echo " done."
    fi

    pidof SysUpdate > /dev/null  2>&1
    if [ $? -ne 0 ]; then
        echo "Running Valetudo"
        echo '|/bin/false' > /proc/sys/kernel/core_pattern
		### ip addr add 203.0.113.1 dev lo
        if [ -f "/root/bin/busybox" ]; then
            (
                # Make valetudo very likely to get killed when out of memory
                echo 1000 > /proc/self/oom_score_adj
                # Also run it with absolutely lowest CPU and I/O priority to not disturb anything critical on robot
                exec VALETUDO_CONFIG_PATH=/mnt/data/valetudo_config.json /root/bin/busybox ionice -c3 nice -n19 /usr/local/bin/valetudo >> /var/log/upstart/valetudo.log 2>&1
            )
        else
            VALETUDO_CONFIG_PATH=/mnt/data/valetudo_config.json nice -n 19 /usr/local/bin/valetudo >> /var/log/upstart/valetudo.log 2>&1
        fi
    else
        echo "Waiting for SysUpdate to finish..."
    fi
done
