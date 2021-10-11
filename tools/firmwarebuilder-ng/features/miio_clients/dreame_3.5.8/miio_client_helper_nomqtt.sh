#!/bin/sh
#
# version: 3.5.8
# date: 2019/12/13
#
# set -x
source /usr/bin/config
WIFI_START_SCRIPT="/usr/bin/wifi_start.sh"
MIIO_RECV_LINE="/usr/bin/miio_recv_line"
MIIO_SEND_LINE="/usr/bin/miio_send_line"
JSHON="/usr/bin/jshon"
WIFI_NODE="wlan0"
WIFI_MAX_RETRY=5
WIFI_RETRY_INTERVAL=3
WIFI_SSID=

GLIBC_TIMEZONE_DIR="/usr/share/zoneinfo"
UCLIBC_TIMEZONE_DIR="/usr/share/zoneinfo/uclibc"

LINK_TIMEZONE_FILE="/data/config/system/localtime"
TIMEZONE_DIR="/usr/share/zoneinfo"

WPA_SUPPLICANT_SOCKET="/data/config/wifi/sockets"

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

send_helper_ready() {
    ready_msg="{\"method\":\"_internal.helper_ready\"}"
    log "$ready_msg"
    $MIIO_SEND_LINE "$ready_msg"
}

req_wifi_conf_status() {
    wificonf_dir=$1
    wificonf_dir=${wificonf_dir##*params\":\"}
    wificonf_dir=${wificonf_dir%%\"*}
    wificonf_dir=`echo $wificonf_dir | xargs echo`
    wificonf_file=${wificonf_dir}/wifi.conf

    REQ_WIFI_CONF_STATUS_RESPONSE=""
    if [ -e $wificonf_file ]; then
        REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":1}"

        WIFI_SSID=`cat $wificonf_file | grep ssid`
        WIFI_SSID=${WIFI_SSID#*ssid=\"}
        WIFI_SSID=${WIFI_SSID%\"*}
        WIFI_SSID=${WIFI_SSID//\\/\\\\}
        WIFI_SSID=${WIFI_SSID//\"/\\\"}
        log "WIFI_SSID: $WIFI_SSID"
    else
        REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":0}"
    fi
}

request_dinfo() {
    dinfo_dir=$1
    dinfo_dir=${dinfo_dir##*params\":\"}
    dinfo_dir=${dinfo_dir%%\"*}
    dinfo_dir=`echo $dinfo_dir | xargs echo`
    dinfo_file=${dinfo_dir}/device.conf

    dinfo_did=`cat $dinfo_file | grep -v ^# | grep did= | tail -1 | cut -d '=' -f 2`
    dinfo_key=`cat $dinfo_file | grep -v ^# | grep key= | tail -1 | cut -d '=' -f 2`
    dinfo_vendor=`cat $dinfo_file | grep -v ^# | grep vendor= | tail -1 | cut -d '=' -f 2`
    dinfo_mac=`cat $dinfo_file | grep -v ^# | grep mac= | tail -1 | cut -d '=' -f 2`
    dinfo_model=`cat $dinfo_file | grep -v ^# | grep model= | tail -1 | cut -d '=' -f 2`
    RESPONSE_DINFO="{\"method\":\"_internal.response_dinfo\",\"params\":{"
    if [ x$dinfo_did != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO\"did\":$dinfo_did"
    fi
    if [ x$dinfo_key != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"key\":\"$dinfo_key\""
    fi
    if [ x$dinfo_vendor != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"vendor\":\"$dinfo_vendor\""
    fi
    if [ x$dinfo_mac != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"mac\":\"$dinfo_mac\""
    fi
    if [ x$dinfo_model != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"model\":\"$dinfo_model\""
    fi
    RESPONSE_DINFO="$RESPONSE_DINFO}}"
}

request_dtoken() {
    dtoken_string=$1
    dtoken_dir=${dtoken_string##*dir\":\"}
    dtoken_dir=${dtoken_dir%%\"*}
    dtoken_dir=`echo $dtoken_dir | xargs echo`
    dtoken_token=${dtoken_string##*ntoken\":\"}
    dtoken_token=${dtoken_token%%\"*}

    dtoken_file=${dtoken_dir}/device.token
    dcountry_file=${dtoken_dir}/device.country

    if [ ! -e ${dtoken_dir}/wifi.conf ]; then
        rm -f ${dtoken_file}
    fi

    if [ -e ${dtoken_file} ]; then
        dtoken_token=`cat ${dtoken_file}`
    else
        echo ${dtoken_token} > ${dtoken_file}
    fi
    
    if [ -e ${dcountry_file} ]; then
        dcountry_country=`cat ${dcountry_file}`
    else
        dcountry_country=""
    fi

    RESPONSE_DTOKEN="{\"method\":\"_internal.response_dtoken\",\"params\":\"${dtoken_token}\"}"
    RESPONSE_DCOUNTRY="{\"method\":\"_internal.response_dcountry\",\"params\":\"${dcountry_country}\"}"
}

save_wifi_conf() {
    datadir=$1
    miio_ssid=$2
    miio_passwd=$3
    miio_uid=$4
    miio_country=$5
    if [ x"$miio_passwd" = x ]; then
        miio_key_mgmt="NONE"
    else
        miio_key_mgmt="WPA"
    fi

    datadir=`echo $datadir | xargs echo`

    echo ssid=\"$miio_ssid\" > $datadir/wifi.conf
    echo psk=\"$miio_passwd\" >> $datadir/wifi.conf
    echo key_mgmt=$miio_key_mgmt >> $datadir/wifi.conf
    if [ $miio_uid -ne 0 ]; then
        echo uid=$miio_uid >> $datadir/wifi.conf
    fi
    echo $miio_uid > $datadir/device.uid
    echo $miio_country > $datadir/device.country
}

clear_wifi_conf() {
    datadir=$1
    rm -f $datadir/wifi.conf
    rm -f $datadir/device.uid
    rm -f $datadir/device.country
}

save_tz_conf() {
    new_tz=$TIMEZONE_DIR/$1
    if [ -f "$new_tz" ]; then
        unlink $LINK_TIMEZONE_FILE
        ln -sf  $new_tz $LINK_TIMEZONE_FILE
        log "timezone set success:$new_tz"
    else
        log "timezone is not exist:$new_tz"
    fi
    avacmd msg_cvt '{"type":"msgCvt","cmd":"config_tz"}' &
}

sanity_check() {
    if [ ! -e $WIFI_START_SCRIPT ]; then
        log "Can't find wifi_start.sh: $WIFI_START_SCRIPT"
        log "Please change $WIFI_START_SCRIPT"
        exit 1
    fi
}

main() {
    IOT_TYPE=miiot
    if [ ! -f $IOT_FLAG ]; then
        touch $IOT_FLAG
    fi
    while true; do
    BUF=`$MIIO_RECV_LINE`
    if [ $? -ne 0 ]; then
        sleep 1;
        continue
    fi

    log "receive:  $BUF"

    if contains "$BUF" "_internal.info"; then
        STRING=`wpa_cli status`

        ifname=${STRING#*\'}
        ifname=${ifname%%\'*}
        log "ifname: $ifname"

        ssid=`wpa_cli status | grep -w 'ssid' | awk -F "ssid=" '{print $2}'`
        ssid=$(echo -e $ssid | sed -e 's/\\/\\\\/g' -e 's/\\\\\"/\\\"/g')
        if [[ -z "${ssid}" ]]; then
            if [ "x$WIFI_SSID" != "x" ]; then
                ssid=${WIFI_SSID}
            else
                if [ -e $WIFI_CONF_PATH ]; then
                    STRING_SSID=`cat $WIFI_CONF_PATH | grep ^ssid`
                    ssid=${STRING_SSID##*ssid=\"}
                    ssid=${ssid%%\"*}
                    ssid=${ssid//\\/\\\\}
                    ssid=${ssid//\"/\\\"}
                fi
            fi
        fi
        log "ssid: $ssid"

        bssid=${STRING##*bssid=}
        bssid=`echo ${bssid} | cut -d ' ' -f 1 | tr '[:lower:]' '[:upper:]'`
        log "bssid: $bssid"

        ip=${STRING##*ip_address=}
        ip=`echo ${ip} | cut -d ' ' -f 1`
        log "ip: $ip"

#        STRING=`ifconfig ${ifname}`
        STRING=`ifconfig ${WIFI_NODE}`

        netmask=${STRING##*Mask:}
        netmask=`echo ${netmask} | cut -d ' ' -f 1`
        log "netmask: $netmask"

        gw=`route -n|grep 'UG'|tr -s ' ' | cut -f 2 -d ' '`
        log "gw: $gw"

        # get vendor and then version
        vendor=`grep "vendor" /etc/miio/device.conf | cut -f 2 -d '=' | tr '[:lower:]' '[:upper:]'`
#        sw_version=`grep "${vendor}_VERSION" /etc/os-release | cut -f 2 -d '='`
        sw_version=`grep "fw_arm_ver" /etc/os-release | cut -f 2 -d ':'`
        sw_version=`echo ${sw_version} | sed 's/\"//g'`
        if [ -z $sw_version ]; then
            sw_version="unknown"
        fi

        rssi=`iw ${WIFI_NODE} link | grep signal | cut -d ' ' -f 2`

        msg="{\"method\":\"_internal.info\",\"partner_id\":\"\",\"params\":{\
\"hw_ver\":\"Linux\",\"fw_ver\":\"$sw_version\",\
\"ap\":{\
 \"ssid\":\"$ssid\",\"bssid\":\"$bssid\",\"rssi\":$rssi\
},\
\"netif\":{\
 \"localIp\":\"$ip\",\"mask\":\"$netmask\",\"gw\":\"$gw\"\
}}}"

        log "$msg"
        $MIIO_SEND_LINE "$msg"
    elif contains "$BUF" "_internal.req_wifi_conf_status"; then
        log "Got _internal.req_wifi_conf_status"
        req_wifi_conf_status "$BUF"
        log "$REQ_WIFI_CONF_STATUS_RESPONSE"
        $MIIO_SEND_LINE "$REQ_WIFI_CONF_STATUS_RESPONSE"
    elif contains "$BUF" "_internal.wifi_start"; then
        # TODO: add lock to /data/config/ava/iot.flag
        content=`cat $IOT_FLAG`
        if [ "x$content" == "x" ]; then
            echo -n $IOT_TYPE > $IOT_FLAG
            log "set SDK($IOT_TYPE) to $IOT_FLAG"
        elif [ "x$content" != "x$IOT_TYPE" ];then
            log "other SDK($content) already set $IOT_FLAG"
            continue
        else
            log "already set current SDK($content) to $IOT_FLAG"
        fi
        wificonf_dir2=$(echo "$BUF" | $JSHON -e params -e datadir -u)
        miio_ssid=$(echo "$BUF" | $JSHON -e params -e ssid -u)
        miio_passwd=$(echo "$BUF" | $JSHON -e params -e passwd -u)
        miio_uid=$(echo "$BUF" | $JSHON -e params -e uid -u)
        miio_country=$(echo "$BUF" | $JSHON -e params -e country_domain -u)
        miio_tz=$(echo "$BUF" | $JSHON -e params -e tz -u)

        log "miio_ssid: $miio_ssid"
        log "miio_country: $miio_country"
        log "miio_tz: $miio_tz"

        save_wifi_conf "$wificonf_dir2" "$miio_ssid" "$miio_passwd" $miio_uid "$miio_country"
        save_tz_conf "$miio_tz"

        CMD=$WIFI_START_SCRIPT
        RETRY=1
        WIFI_SUCC=1
        until [ $RETRY -gt $WIFI_MAX_RETRY ]
        do
        WIFI_SUCC=1
        log "Retry $RETRY: CMD=${CMD}"
        ${CMD} && break
        WIFI_SUCC=0

        if [ $WIFI_MAX_RETRY -eq 1 ]; then
           break
        fi
        let RETRY=$RETRY+1
        sleep $WIFI_RETRY_INTERVAL
        done

        if [ $WIFI_SUCC -eq 1 ]; then
        msg="{\"method\":\"_internal.wifi_connected\"}"
        log "$msg"
        $MIIO_SEND_LINE "$msg"
        else
        clear_wifi_conf $wificonf_dir2
        CMD=$WIFI_START_SCRIPT
        log "Back to AP mode, CMD=${CMD}"
        ${CMD}
        msg="{\"method\":\"_internal.wifi_ap_mode\",\"params\":null}";
        log "$msg"
        $MIIO_SEND_LINE "$msg"
        fi
    elif contains "$BUF" "_internal.request_dinfo"; then
        log "Got _internal.request_dinfo"
        request_dinfo "$BUF"
        log "$RESPONSE_DINFO"
        $MIIO_SEND_LINE "$RESPONSE_DINFO"
    elif contains "$BUF" "_internal.request_dtoken"; then
        log "Got _internal.request_dtoken"
        request_dtoken "$BUF"
        log "$RESPONSE_DCOUNTRY"
        $MIIO_SEND_LINE "$RESPONSE_DCOUNTRY"
        #echo $RESPONSE_DTOKEN
        $MIIO_SEND_LINE "$RESPONSE_DTOKEN"
    elif contains "$BUF" "_internal.config_tz"; then
        log "Got _internal.config_tz"
        miio_tz=$(echo "$BUF" | $JSHON -e params -e tz -u -Q)
        save_tz_conf "$miio_tz"
    else
        log "Unknown cmd: $BUF"
    fi
    done
}

sanity_check
send_helper_ready
main
