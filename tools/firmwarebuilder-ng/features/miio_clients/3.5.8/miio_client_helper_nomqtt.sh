#!/bin/bash

WIFI_START_SCRIPT=$WIFI_START_PATH/$WIFI_START_NAME
WIFI_CONF_FILE=$WIFI_CONF_PATH/$WIFI_CONF_NAME

if [ -z "$MIIO_RECV_LINE" ]; then
	MIIO_RECV_LINE=miio_recv_line
fi

if [ -z "$MIIO_SEND_LINE" ]; then
	MIIO_SEND_LINE=miio_send_line
fi
WIFI_MAX_RETRY=5
WIFI_RETRY_INTERVAL=3
WIFI_SSID=
DATA_DIR=""


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
    echo $ready_msg
    $MIIO_SEND_LINE "$ready_msg"
}

req_wifi_conf_status() {
    wificonf_dir=$1
    wificonf_dir=${wificonf_dir##*params\":\"}
    wificonf_dir=${wificonf_dir%%\"*}
    wificonf_file=${wificonf_dir}/wifi.conf

    REQ_WIFI_CONF_STATUS_RESPONSE=""
    if [ -e $wificonf_file ]; then
	REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":1}"

	WIFI_SSID=`cat $wificonf_file | grep ssid`
	WIFI_SSID=${WIFI_SSID#*ssid=\"}
	WIFI_SSID=${WIFI_SSID%\"*}
    else
	REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":0}"
    fi
}

request_dinfo() {
    dinfo_dir=$1
    dinfo_dir=${dinfo_dir##*params\":\"}
    dinfo_dir=${dinfo_dir%%\"*}
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

request_dcountry(){
	dcountry_string=$1
	dcountry_dir=${dcountry_string##*dir\":\"}
    dcountry_dir=${dcountry_dir%%\"*}
    dcountry_country=${dcountry_string##*country_domain\":\"}
	dcountry_country=${dcountry_country%%\"*}
    
    dcountry_file=${dcountry_dir}/device.country
    
    if [ ! -e ${dcountry_dir}/wifi.conf ]; then
	rm -f ${dcountry_file}
    fi
    
    if [ -e ${dcountry_file} ]; then
	dcountry_country=`cat ${dcountry_file}`
    elif [ ! -z $dcountry_country ]; then
	echo ${dcountry_country} > ${dcountry_file}
    fi
    
    RESPONSE_DCOUNTRY="{\"method\":\"_internal.response_dcountry\",\"params\":\"${dcountry_country}\"}"
}

request_dtoken() {
    dtoken_string=$1
    dtoken_dir=${dtoken_string##*dir\":\"}
    dtoken_dir=${dtoken_dir%%\"*}
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

update_dtoken()
{
    update_token_string=$1
    update_dtoken=${update_token_string##*ntoken\":\"}
    update_token=${update_dtoken%%\"*}
    MIIO_TOKEN_FILE=${DATA_DIR}/device.token
    if [ -e ${MIIO_TOKEN_FILE} ]; then
        rm -rf ${MIIO_TOKEN_FILE}
        echo ${update_token} > ${MIIO_TOKEN_FILE}
        RESPONSE_UPDATE_TOKEN="{\"method\":\"_internal.token_updated\",\"params\":\"${update_token}\"}"
    fi
}

save_wifi_conf() {
    datadir=$1
    miio_ssid=$2
    miio_passwd=$3
    miio_uid=$4
    miio_country=$5

    miio_uid_old=""

    #When xiaomi router sends config_router to device, there is no uid or uid equals 0(xiaomi bug),
    #so we need to keep the uid/country in old wifi.conf
    if [ -f $datadir/wifi.conf ]; then
        miio_uid_old=`cat $datadir/wifi.conf |grep "uid=" |sed -e 's/\n$//' |sed -e 's/\r$//' |sed -e 's/^.*uid=//'`
    fi 

    echo "ssid=\"$miio_ssid\"" > $datadir/wifi.conf
    if [ x"$miio_passwd" = x ]; then
	miio_key_mgmt="NONE"
    else
	miio_key_mgmt="WPA"
	echo "psk=\"$miio_passwd\"" >> $datadir/wifi.conf
    fi
    echo key_mgmt=$miio_key_mgmt >> $datadir/wifi.conf

    if [ "x$miio_uid" = "x" ]; then
        miio_uid=0
    fi
    if [ ${#miio_uid} -gt 1 ]; then
        echo "uid=$miio_uid" >> $datadir/wifi.conf
        echo "$miio_uid" > $datadir/device.uid
    else
        echo "uid=$miio_uid_old" >> $datadir/wifi.conf
    fi

    #We must make sure resetting wifi has already removed device.country,
    #otherwise if change the server from US to China, device.country won't be
    #overwritten and "us" will be kept.
    if [ "x$miio_country" != "x" ]; then
        echo $miio_country > $datadir/device.country
    fi
}

clear_wifi_conf() {
    datadir=$1
    rm -f $datadir/wifi.conf
    rm -f $datadir/device.uid
    rm -f $datadir/device.country
}

save_tz_conf() {
	new_tz="/usr/share/zoneinfo/$1"
    # new_tz must be an ordinary file, cannot be directory
	if [ -f "$new_tz" ]; then
        cp $new_tz /mnt/data/rockrobo/localtime
        echo -n "$1" > /mnt/data/rockrobo/timezone
        echo "timezone set success:$new_tz"
	else
        echo "timezone does not exist:$new_tz"
	fi
}

sanity_check() {
    if [ ! -e $WIFI_START_SCRIPT ]; then
	echo "Can't find wifi_start.sh: $WIFI_START_SCRIPT"
	echo 'Please change $WIFI_START_SCRIPT'
	exit 1
    fi
}

main() {
    while true; do
	BUF=`$MIIO_RECV_LINE`
    BUF=${BUF//\\\//\/}
	if [ $? -ne 0 ]; then
	    sleep 1;
	    continue
	fi
	if contains "$BUF" "_internal.info"; then
	    STRING=`wpa_cli status`

            flag=0
	    ifname=${STRING#*\'}
	    ifname=${ifname%%\'*}
	    echo "ifname: $ifname"

            file_type=`file $WIFI_CONF_FILE`
            echo "file_type: $file_type"

            ret=`echo $file_type | grep "ASCII text"`
	    if [ "x${ret}" != "x" ]; then
                echo "ASCII text ssid"
                flag=0
            else
                flag=1
            fi

	    if [ "x$WIFI_SSID" != "x" ]; then
		ssid=$WIFI_SSID
	    else
                if [ "$flag" = "0" ]; then
			ssid=${STRING##*ssid=}
			# bug fix for 2615
			ssid=`echo ${ssid} | awk -F "id=" '{print $1}'`
		else
                	ssid=`cat ${WIFI_CONF_FILE} | grep ^ssid| sed 's/ssid=//g'`
                	len=${#ssid}
                	echo "len 1: $len"
                	len=`expr $len - 1`
                	echo "len 2: $len"
                	ssid=`echo ${ssid} | cut -c 2-${len}`
			ssid=`echo $ssid | sed 's/\"/\\\"/g'`
		fi
	    fi
	    # handle special char, e.g.: '"', '\'
	    # Here we're using sed, we might switch to jshon
	    ssid=$(echo $ssid | sed -e 's/^"/\\"/' | sed -e 's/\([^\]\)"/\1\\"/g' | sed -e 's/\([^\]\)"/\1\\"/g' | sed -e 's/\([^\]\)\(\\[^"\\\/bfnrtu]\)/\1\\\2/g' | sed -e 's/\([^\]\)\\$/\1\\\\/')

	    bssid=${STRING##*bssid=}
	    bssid=`echo ${bssid} | cut -d ' ' -f 1 | tr '[a-z]' '[A-Z]'`

	    ip=${STRING##*ip_address=}
	    ip=`echo ${ip} | cut -d ' ' -f 1`

	    STRING=`ifconfig ${ifname}`

	    netmask=${STRING##*Mask:}
	    netmask=`echo ${netmask} | cut -d ' ' -f 1`

	    gw=`route -n|grep 'UG'|tr -s ' ' | cut -f 2 -d ' '`

	    # get vendor and then version
	    vendor=`grep "vendor" $RR_DEFAULT/device.conf | cut -f 2 -d '=' | tr '[a-z]' '[A-Z]'`
        if [ -f /opt/rockrobo/rr-release ]; then
            sw_version=`grep "${vendor}_VERSION" /opt/rockrobo/rr-release | cut -f 2 -d '='`
        else
            sw_version=`grep "${vendor}_VERSION" /etc/os-release | cut -f 2 -d '='`
        fi

	    if [ -z $sw_version ]; then
		sw_version="unknown"
	    fi
	    
	    rssi=""
        if [ -e /proc/net/rtl8189es/wlan0/rx_signal ]; then
            rssi=`cat /proc/net/rtl8189es/wlan0/rx_signal |grep "rssi:" |sed -e 's/rssi://'`
        else
            rssi=`wpa_cli -i wlan0 signal_poll |grep "RSSI=" |sed -e 's/RSSI=//'`
        fi 
	    if [ -z $rssi ]; then
		rssi="-50"
	    fi

	    msg="{\"method\":\"_internal.info\",\"partner_id\":\"\",\"params\":{\
\"hw_ver\":\"Linux\",\"fw_ver\":\"$sw_version\",\
\"ap\":{\
 \"ssid\":\"$ssid\",\"bssid\":\"$bssid\",\"rssi\":$rssi\
},\
\"netif\":{\
 \"localIp\":\"$ip\",\"mask\":\"$netmask\",\"gw\":\"$gw\"\
}}}"

	    $MIIO_SEND_LINE "$msg"
	elif contains "$BUF" "_internal.req_wifi_conf_status"; then
	    echo "Got _internal.req_wifi_conf_status"
	    req_wifi_conf_status "$BUF"
	    $MIIO_SEND_LINE "$REQ_WIFI_CONF_STATUS_RESPONSE"
	elif contains "$BUF" "_internal.wifi_start"; then
	    wificonf_dir2=${BUF##*\"datadir\":\"}
	    wificonf_dir2=${wificonf_dir2%%\"*}
        wificonf_dir2=${wificonf_dir2//\\/}
	    miio_ssid=${BUF##*\"ssid\":\"}
	    miio_ssid=${miio_ssid%%\",\"passwd\":\"*}
	    miio_passwd=${BUF##*\",\"passwd\":\"}
	    miio_passwd=${miio_passwd%%\",\"uid\":\"*}
	    miio_uid=${BUF##*\",\"uid\":\"}
	    miio_uid=${miio_uid%%\"*}
	    miio_country=${BUF##*\",\"country_domain\":\"}
	    miio_country=${miio_country%%\"*}
	    tz=${BUF##*\",\"tz\":\"}
	    tz=${tz%%\"*}
        tz=${tz//\\/}

	    save_wifi_conf "$wificonf_dir2" "$miio_ssid" "$miio_passwd" "$miio_uid" "$miio_country"
	    DATA_DIR=$wificonf_dir2
	    save_tz_conf "$tz"

	    CMD=$WIFI_START_SCRIPT
	    RETRY=1
	    WIFI_SUCC=1
	    until [ $RETRY -gt $WIFI_MAX_RETRY ]
	    do
		WIFI_SUCC=1
		echo "Retry $RETRY: CMD=${CMD}"
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
		echo $msg
		$MIIO_SEND_LINE "$msg"
	    else
		clear_wifi_conf $wificonf_dir2
		CMD=$WIFI_START_SCRIPT
		echo "Back to AP mode, CMD=${CMD}"
		${CMD}
		msg="{\"method\":\"_internal.wifi_ap_mode\",\"params\":null}";
		echo $msg
		$MIIO_SEND_LINE "$msg"
	    fi
    elif contains "$BUF" "_internal.wifi_reconnect"; then
        echo "Got _internal.wifi_reconnect"
        #we recommend open the note below to reconnect wifi at background
        #$WIFI_START_SCRIPT &
    elif contains "$BUF" "_internal.wifi_reload"; then
        echo "Got _internal.wifi_reload"
        #rmmod xxx    remove wifi driver   
        #insmod xxx   load wifi driver
        #sleep 1
        #$WIFI_START_SCRIPT &
	elif contains "$BUF" "_internal.request_dinfo"; then
	    echo "Got _internal.request_dinfo"
	    request_dinfo "$BUF"
	    $MIIO_SEND_LINE "$RESPONSE_DINFO"
	elif contains "$BUF" "_internal.request_dtoken"; then
	    echo "Got _internal.request_dtoken"
	    request_dtoken "$BUF"
	    $MIIO_SEND_LINE "$RESPONSE_DTOKEN"
	    $MIIO_SEND_LINE "$RESPONSE_DCOUNTRY"
	elif contains "$BUF" "_internal.update_dtoken"; then
	    update_dtoken "$BUF"
	    $MIIO_SEND_LINE "$RESPONSE_UPDATE_TOKEN"
	elif contains "$BUF" "_internal.config_tz"; then
	    echo "Got _internal.config_tz"
	    tz=${BUF##*\",\"tz\":\"}
	    tz=${tz%%\"*}

	    save_tz_conf "$tz"
	else
	    echo "Unknown cmd: $BUF"
	fi
    done
}

sanity_check
send_helper_ready
main
