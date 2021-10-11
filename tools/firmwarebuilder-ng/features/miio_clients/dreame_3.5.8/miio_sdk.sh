#!/bin/sh
#
# Date: 2021.01
# Version: 0.0.1
#
#set -x

source /usr/bin/config

do_start() {
    /etc/rc.d/miio.sh
}

do_stop() {
    touch ${RESTART_MIIO} && sync
    /etc/rc.d/miio.sh stop
    sleep 0.1
    killall -9 wifi_start.sh > /dev/null 2>&1
    sleep 0.1
    killall -9 wifi_setup.sh > /dev/null 2>&1
    rm -f ${MIIO_TOKEN_FILE} && sync
}

do_restart() {
    rm -f ${MIIO_COUNTRY_FILE} ${MIIO_UID_FILE} > /dev/null 2>&1

    # restart miio sdk if has wifi.conf
    if [ -f ${WIFI_CONF_FILE} -o ! -f ${MIIO_TOKEN_FILE} ]
    then
        avacmd iot '{"type":"iot", "notify":"close_server"}' &
        sleep 0.2

        touch ${RESTART_MIIO}
        rm -f ${WIFI_CONF_FILE}
        sync
        killall miio_client_helper_nomqtt.sh
        killall miio_recv_line miio_agent
        killall miio_client
        sleep 0.2
        /etc/rc.d/miio.sh
        (sleep 2 && rm -f ${RESTART_MIIO}) &
        sleep 0.2
        avacmd iot '{"type":"iot", "notify":"open_server"}' &
    fi
}

do_check_netcfg() {
    if [ ! -f ${WIFI_CONF_FILE} ]; then
        touch ${FACTORY_AP_FILE}
    else
        rm -f ${FACTORY_AP_FILE}
    fi
}

case "$1" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_restart
        ;;
    check_netcfg)
        do_check_netcfg
        ;;
    *)
        log "$0 parameter error"
        ;;
esac
