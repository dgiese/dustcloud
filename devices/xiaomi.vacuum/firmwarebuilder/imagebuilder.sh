#!/bin/sh
# Author: Dennis Giese [dgiese@dontvacuum.me]
# Copyright 2017 by Dennis Giese

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program. If not, see <http://www.gnu.org/licenses/>.
#

set -eu

cleanup()
{
    [ -n "${FW_TMPDIR+x}" ] && echo "Cleaning up"
    [ -n "${FW_DIR+x}" ]    && [ -f "$FW_DIR/disk.img" ] && rm "$FW_DIR/disk.img"
    [ -n "${PATCHED+x}" ]   && [ -f "${PATCHED}.cpt" ]   && rm "${PATCHED}.cpt"
    [ -n "${FIRMWARE_FILENAME+x}" ] && [ -f "$FW_DIR/$FIRMWARE_FILENAME" ] && rm "$FW_DIR/$FIRMWARE_FILENAME"
    [ -n "${FW_DIR+x}" ]    && [ -d "$FW_DIR" ]          && rmdir "$FW_DIR"
    [ -n "${FW_TMPDIR+x}" ] && [ -d "$FW_TMPDIR/image" ] && rmdir "$FW_TMPDIR/image"
    [ -n "${FW_TMPDIR+x}" ] && [ -d "$FW_TMPDIR" ]       && rmdir "$FW_TMPDIR"
}
trap cleanup EXIT

print_usage()
{
echo "Usage: sudo $(basename $0) --firmware=v11_003194.pkg [--soundfile=english.pkg|
--public-key=id_rsa.pub|--timezone=Europe/Berlin|--disable-firmware-updates|
--dummycloud-path=PATH|--valetudo-path=PATH|--replace-adbd|--rrlogd-patcher=PATCHER|
--disable-logs|--hostname=HOSTNAME|--enable-ruby|--ntpserver=ADDRESS|
--unprovisioned|--help]"
}

print_help()
{
    cat << EOF

Options:
  -f, --firmware=PATH        Path to firmware file
  -s, --soundfile=PATH       Path to sound file
  -k, --public-key=PATH      Path to ssh public key to be added to authorized_keys file
                             if need to add multiple keys set -k as many times as you need:
                             -k ./local_key.pub -k ~/.ssh/id_rsa.pub -k /root/ssh/id_rsa.pub
  -t, --timezone             Timezone to be used in vacuum
  --disable-firmware-updates Disable xiaomi servers using hosts file for firmware updates
  --dummycloud-path=PATH     Provide the path to dummycloud
  --valetudo-path=PATH       The path to valetudo to include it into the image
  --replace-adbd             Replace xiaomis custom adbd with generic adbd version
  --rrlogd-patcher=PATCHER   Patch rrlogd to disable log encryption (only use with dummycloud or dustcloud)
  --disable-logs             Disables most log files creations and log uploads on the vacuum
  --hostname=HOSTNAME        Sets a custom hostname. If not set the default 'roborock' is used.
  --enable-ruby              Restores user ruby (can do sudo) and assigns a random password
  --ntpserver=ADDRESS        Set your local NTP server
  --unprovisioned            Access your network in unprovisioned mode (currently only wpa2psk is supported)
                             --unprovisioned wpa2psk
                             --ssid YOUR_SSID
                             --psk YOUR_WIRELESS_PASSWORD
  -h, --help                 Prints this message

Each parameter that takes a file as an argument accepts path in any form

Report bugs to: https://github.com/dgiese/dustcloud/issues
EOF
}

fixed_cmd_subst() {
    eval '
    '"$1"'=$('"$2"'; ret=$?; echo .; exit "$ret")
    set -- "$1" "$?"
    '"$1"'=${'"$1"'%??}
    '
    return "$2"
}

readlink_f() (
    link=$1 max_iterations=40
    while [ "$max_iterations" -gt 0 ]; do
        max_iterations=$(($max_iterations - 1))
        fixed_cmd_subst dir 'dirname -- "$link"' || exit
        fixed_cmd_subst base 'basename -- "$link"' || exit
        cd -P -- "$dir" || exit
        link=${PWD%/}/$base
        if [ ! -L "$link" ]; then
            printf '%s\n' "$link"
            exit
        fi
        fixed_cmd_subst link 'ls -ld -- "$link"' || exit
        link=${link#* -> }
    done
    printf >&2 'Loop detected\n'
    exit 1
)

# https://www.etalabs.net/sh_tricks.html
arrsave()
(
    for i; do
        printf %s\\n "$i" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/' \\\\/"
    done
    echo " "
)

arrappend()
(
    item=$1
    shift
    eval "set -- $@"
    arrsave "$@" "$item"
)

PUBLIC_KEYS=
RESTORE_RUBY=0
PATCH_ADBD=0
DISABLE_XIAOMI=0
UNPROVISIONED=0
DISABLE_LOGS=0
ENABLE_DUMMYCLOUD=0
ENABLE_VALETUDO=0
PATCH_RRLOGD=0
SOUNDFILE_PATH=
CUSTOM_HOSTNAME=

while [ -n "${1+x}" ]; do
    PARAM="$1"
    ARG="${2+}"
    shift
    case ${PARAM} in
        *-*=*)
            ARG=${PARAM#*=}
            PARAM=${PARAM%%=*}
            set -- "----noarg=${PARAM}" "$@"
    esac
    case ${PARAM} in
        *-help|-h)
            print_usage
            print_help
            exit 0
            ;;
        *-firmware|-f)
            FIRMWARE_PATH="$ARG"
            shift
            ;;
        *-soundfile|-s)
            SOUNDFILE_PATH="$ARG"
            shift
            ;;
        *-public-key|-k)
            # check if the key file exists
            if [ -r "$ARG" ]; then
                PUBLIC_KEYS=$(arrappend "$(readlink_f "$ARG")" "$PUBLIC_KEYS")
            else
                echo "Public key $ARG doesn't exist or is not readable"
                exit 1
            fi
            shift
            ;;
        *-timezone|-t)
            TIMEZONE="$ARG"
            shift
            ;;
        *-disable-firmware-updates)
            DISABLE_XIAOMI=1
            ;;
        *-disable-logs)
            DISABLE_LOGS=1
            ;;
        *-hostname)
            CUSTOM_HOSTNAME="$ARG"
            shift
            ;;
        *-replace-adbd)
            PATCH_ADBD=1
            ;;
        *-enable-ruby)
            RESTORE_RUBY=1
            ;;
        *-rrlogd-patcher)
            PATCH_RRLOGD=1
            RRLOGD_PATCHER="$ARG"
            shift
            ;;
        *-dummycloud-path)
            DUMMYCLOUD_PATH="$ARG"
            if [ -r "$DUMMYCLOUD_PATH/dummycloud" ]; then
                ENABLE_DUMMYCLOUD=1
            else
                echo "The dummycloud binary hasn't been found in $DUMMYCLOUD_PATH"
                echo "Please download it from https://github.com/dgiese/dustcloud"
                exit 1
            fi
            shift
            ;;
        *-valetudo-path)
            VALETUDO_PATH="$ARG"
            if [ -r "$VALETUDO_PATH/valetudo" ]; then
                ENABLE_VALETUDO=1
            else
                echo "The valetudo binary hasn't been found in $VALETUDO_PATH"
                echo "Please download it from https://github.com/Hypfer/Valetudo"
                exit 1
            fi
            shift
            ;;
        *-ntpserver)
            NTPSERVER="$ARG"
            shift
            ;;
        *-unprovisioned)
            UNPROVISIONED=1
            WIFIMODE="$ARG"
            shift
            ;;
        *-ssid)
            SSID="$ARG"
            shift
            ;;
        *-psk)
            PSK="$ARG"
            shift
            ;;
        ----noarg)
            echo "$ARG does not take an argument"
            exit
            ;;
        -*)
            echo Unknown Option "$PARAM". Exit.
            exit 1
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
done

SCRIPT="$0"
SCRIPTDIR=$(dirname "${0}")
COUNT=0
while [ -L "${SCRIPT}" ]
do
    SCRIPT=$(readlink_f ${SCRIPT})
    COUNT=$(expr ${COUNT} + 1)
    if [ ${COUNT} -gt 100 ]
    then
        echo "Too many symbolic links"
        exit 1
    fi
done
BASEDIR=$(dirname "${SCRIPT}")
echo "Script path: $BASEDIR"

if [ "$(id -u)" -ne 0 ]; then
    GUESTMOUNT="$(command -v guestmount)"
    if [ ! -x "$GUESTMOUNT" ]; then
        echo "guestmount not found! Please install it (e.g. by (apt|brew|dnf|zypper) install libguestfs-tools)"
        exit 1
    fi
fi

IS_MAC=false
case $(uname | tr '[:upper:]' '[:lower:]') in
  darwin*)
    # Mac OSX
    IS_MAC=true
    echo "Running on a Mac, adjusting commands accordingly"
    ;;
  *)
    ;;
esac

if [ $ENABLE_VALETUDO -eq 1  ] && [ $ENABLE_DUMMYCLOUD -eq 1 ]; then
    echo "You can't install Valetudo and Dummycloud at the same time, "
    echo "because Valetudo has implemented Dummycloud fuctionality and map upload support now."
fi

CCRYPT="$(command -v ccrypt)"
if [ ! -x "$CCRYPT" ]; then
    echo "ccrypt not found! Please install it (e.g. by (apt|brew|dnf|zypper) install ccrypt)"
    exit 1
fi

DOS2UNIX="$(command -v dos2unix)"
if [ ! -x "$DOS2UNIX" ]; then
    echo "dos2unix not found! Please install it (e.g. by (apt|brew|dnf|zypper) install dos2unix)"
    exit 1
fi

if [ -z "$PUBLIC_KEYS" ]; then
    echo "No public keys selected!"
    exit 1
fi

SOUNDLANG=${SOUNDLANG:-"en"}
TIMEZONE=${TIMEZONE:-"Europe/Berlin"}
PASSWORD_FW="rockrobo"
PASSWORD_SND="r0ckrobo#23456"

if [ ! -r "$FIRMWARE_PATH" ]; then
    echo "You need to specify an existing firmware file, e.g. v11_003194.pkg"
    exit 1
fi
FIRMWARE_PATH=$(readlink_f "$FIRMWARE_PATH")
FIRMWARE_BASENAME=$(basename $FIRMWARE_PATH)
FIRMWARE_FILENAME="${FIRMWARE_BASENAME%.*}"

if [ -n "$SOUNDFILE_PATH" ]; then
    SOUNDFILE_PATH=$(readlink_f "$SOUNDFILE_PATH")
fi

if [ $PATCH_ADBD -eq 1 ]; then
    if [ ! -f $SCRIPTDIR/adbd ]; then
        echo "File adbd not found, cannot replace adbd in image!"
        exit 1
    fi
fi

# Generate SSH Host Keys
echo "Generate SSH Host Keys if necessary"

if [ ! -r ssh_host_rsa_key ]; then
    ssh-keygen -N "" -t rsa -f ssh_host_rsa_key
fi
if [ ! -r ssh_host_dsa_key ]; then
    ssh-keygen -N "" -t dsa -f ssh_host_dsa_key
fi
if [ ! -r ssh_host_ecdsa_key ]; then
    ssh-keygen -N "" -t ecdsa -f ssh_host_ecdsa_key
fi
if [ ! -r ssh_host_ed25519_key ]; then
    ssh-keygen -N "" -t ed25519 -f ssh_host_ed25519_key
fi

FW_TMPDIR="$(pwd)/$(mktemp -d fw.XXXXXX)"

if [ -n "$SOUNDFILE_PATH" ]; then
    echo "Decrypt soundfile .."
    SND_DIR="$FW_TMPDIR/sounds"
    SND_FILE=$(basename $SOUNDFILE_PATH)
    mkdir -p $SND_DIR
    cp "$SOUNDFILE_PATH" "$SND_DIR/$SND_FILE"
    $CCRYPT -d -K "$PASSWORD_SND" "$SND_DIR/$SND_FILE"

    echo "Unpack soundfile .."
    tar -xzf "$SND_DIR/$SND_FILE" -C "$SND_DIR"
fi

echo "Decrypt firmware"
FW_DIR="$FW_TMPDIR/fw"
mkdir -p "$FW_DIR"
cp "$FIRMWARE_PATH" "$FW_DIR/$FIRMWARE_FILENAME"
$CCRYPT -d -K "$PASSWORD_FW" "$FW_DIR/$FIRMWARE_FILENAME"

echo "Unpack firmware"
tar -C "$FW_DIR" -xzf "$FW_DIR/$FIRMWARE_FILENAME"
if [ ! -r "$FW_DIR/disk.img" ]; then
    echo "File $FW_DIR/disk.img not found! Decryption and unpacking was apparently unsuccessful."
    exit 1
fi

IMG_DIR="$FW_TMPDIR/image"
mkdir -p "$IMG_DIR"

if [ "$IS_MAC" = true ]; then
    #ext4fuse doesn't support write properly
    #ext4fuse disk.img image -o force
    fuse-ext2 "$FW_DIR/disk.img" "$IMG_DIR" -o rw+
elif [ "$(id -u)" -ne 0 ]; then
    $GUESTMOUNT -a "$FW_DIR/disk.img" -m /dev/sda "$IMG_DIR"
else
    mount -o loop "$FW_DIR/disk.img" "$IMG_DIR"
fi

echo "Replace ssh host keys"
cat ssh_host_rsa_key > $IMG_DIR/etc/ssh/ssh_host_rsa_key
cat ssh_host_rsa_key.pub > $IMG_DIR/etc/ssh/ssh_host_rsa_key.pub
cat ssh_host_dsa_key > $IMG_DIR/etc/ssh/ssh_host_dsa_key
cat ssh_host_dsa_key.pub > $IMG_DIR/etc/ssh/ssh_host_dsa_key.pub
cat ssh_host_ecdsa_key > $IMG_DIR/etc/ssh/ssh_host_ecdsa_key
cat ssh_host_ecdsa_key.pub > $IMG_DIR/etc/ssh/ssh_host_ecdsa_key.pub
cat ssh_host_ed25519_key > $IMG_DIR/etc/ssh/ssh_host_ed25519_key
cat ssh_host_ed25519_key.pub > $IMG_DIR/etc/ssh/ssh_host_ed25519_key.pub

echo "Disable SSH firewall rule"
sed -i -E '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf

echo "Add SSH authorized_keys"
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh

if [ -r $IMG_DIR/root/.ssh/authorized_keys ]; then
    echo "Removing obsolete authorized_keys from Xiaomi image"
    rm $IMG_DIR/root/.ssh/authorized_keys
fi

eval "set -- $PUBLIC_KEYS"
while [ -n "${1+x}" ]; do
    cat "$1" >> $IMG_DIR/root/.ssh/authorized_keys
    shift
done
chmod 600 $IMG_DIR/root/.ssh/authorized_keys

if [ $DISABLE_XIAOMI -eq 1 ]; then
    echo "reconfiguring network traffic to xiaomi"
    # comment out this section if you do not want do disable the xiaomi cloud
    # or redirect it
    echo "0.0.0.0       awsbj0-files.fds.api.xiaomi.com" >> $IMG_DIR/etc/hosts
    echo "0.0.0.0       awsbj0.fds.api.xiaomi.com" >> $IMG_DIR/etc/hosts
    #echo "0.0.0.0       ott.io.mi.com" >> ./etc/hosts
    #echo "0.0.0.0       ot.io.mi.com" >> ./etc/hosts
fi

if [ $UNPROVISIONED -eq 1 ]; then
    echo "Implementing unprovisioned mode"
    if [ -z "$WIFIMODE" ]; then
        echo "You need to specify a Wifi Mode: currently only wpa2psk is supported"
        exit 1
    fi
    echo "Wifimode: $WIFIMODE"
    if [ "$WIFIMODE" = "wpa2psk" ]; then

        if [ -z "$SSID" ]; then
            echo "No SSID given, please use --ssid YOURSSID"
            exit 1
        fi
        if [ -z "$PSK" ]; then
            echo "No PSK (Wireless Password) given, please use --psk YOURPASSWORD"
            exit 1
        fi

        mkdir $IMG_DIR/opt/unprovisioned
        install -m 0755 $BASEDIR/unprovisioned/start_wifi.sh $IMG_DIR/opt/unprovisioned

        sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
        cat $BASEDIR/unprovisioned/rc.local >> $IMG_DIR/etc/rc.local
        echo "exit 0" >> $IMG_DIR/etc/rc.local

        install -m 0644 $BASEDIR/unprovisioned/wpa_supplicant.conf.wpa2psk $IMG_DIR/opt/unprovisioned/wpa_supplicant.conf

        sed -i 's/#SSID#/'"$SSID"'/g' $IMG_DIR/opt/unprovisioned/wpa_supplicant.conf
        sed -i 's/#PSK#/'"$PSK"'/g'   $IMG_DIR/opt/unprovisioned/wpa_supplicant.conf
    fi
fi

if [ $PATCH_ADBD -eq 1 ]; then
    echo "replacing adbd"
    cp $IMG_DIR/usr/bin/adbd $IMG_DIR/usr/bin/adbd.xiaomi
    install -m 0755 $BASEDIR/adbd $IMG_DIR/usr/bin/adbd
fi

if [ $DISABLE_LOGS -eq 1 ]; then
    # Set LOG_LEVEL=3
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    #UPLOAD_METHOD=0
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Let the script cleanup logs
    sed -i 's/nice.*//' $IMG_DIR/opt/rockrobo/rrlog/tar_extra_file.sh

    # Add exit 0
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/misc.sh
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/toprotation.sh
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/topstop.sh

    # Comment $IncludeConfig
    sed -Ei 's/^(\$IncludeConfig)/#&/' $IMG_DIR/etc/rsyslog.conf
fi

if [ -n "$CUSTOM_HOSTNAME" ]; then
    echo "Set '$CUSTOM_HOSTNAME' as hostname"
    
    sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
    echo "hostname $CUSTOM_HOSTNAME && echo $CUSTOM_HOSTNAME > /etc/hostname" >> $IMG_DIR/etc/rc.local
    echo >> $IMG_DIR/etc/rc.local
    echo "exit 0" >> $IMG_DIR/etc/rc.local
fi

if [ $PATCH_RRLOGD -eq 1 ]; then
    PYTHON=${PYTHON:-"python3"}
    RRLOGD_PATCHER_ABS="$(readlink_f $RRLOGD_PATCHER 2> /dev/null)"

    if [ -r "$RRLOGD_PATCHER_ABS" ]; then
        echo "Creating backup of rrlogd"
        cp $IMG_DIR/opt/rockrobo/rrlog/rrlogd $IMG_DIR/opt/rockrobo/rrlog/rrlogd.xiaomi

        # This is a extremly simple binary patch by John Rev
        # In the long run we should use his rrlogd-patcher however we would need to integrate
        # it into the imagebuilder package or git repo.
        #
        # See https://github.com/JohnRev/rrlogd-patcher
        echo "Trying to patch rrlogd"
        cp $IMG_DIR/opt/rockrobo/rrlog/rrlogd $FW_TMPDIR/rrlogd

        env --chdir="$FW_TMPDIR" $PYTHON "$RRLOGD_PATCHER_ABS"
        ret=$?
        if [ $ret -eq 0 ]; then
            install -m 0755 $FW_TMPDIR/rrlogd_patch $IMG_DIR/opt/rockrobo/rrlog/rrlogd
            echo "Successfully patched rrlogd"
        else
            echo "Failed to patch rrlogd (please report a bug here: https://github.com/JohnRev/rrlogd-patcher/issues)"
        fi
    else
        echo "Invalid path to rrlogd ($RRLOGD_PATCHER_ABS)"
    fi
fi

if [ $RESTORE_RUBY -eq 1 ]; then
    echo "Generate random password for user ruby"
    USER_PASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};echo;`
    #original password (<=v3254) file has the following credentials:
    #   root:rockrobo
    #   ruby:rockrobo
    echo "Restore old usertable to enable user ruby"
    install -m 0644 $IMG_DIR/etc/passwd- $IMG_DIR/etc/passwd
    install -m 0644 $IMG_DIR/etc/group-  $IMG_DIR/etc/group
    install -m 0644 $IMG_DIR/etc/shadow- $IMG_DIR/etc/shadow
    #cp ./etc/gshadow- ./etc/gshadow
    #cp ./etc/subuid- ./etc/subuid
    #cp ./etc/subgid- ./etc/subgid
    #if this fails, then the password is rockrobo for user ruby
    echo "ruby:$USER_PASSWORD" | chpasswd -c SHA512 -R $PWD
    echo $USER_PASSWORD > "output/${FIRMWARE_FILENAME}.password"
    ###
fi

if [ $ENABLE_DUMMYCLOUD -eq 1 ]; then
    echo "Installing dummycloud"

    # Fix line endings as the released zip packages have Windows line endings
    dos2unix $DUMMYCLOUD_PATH/doc/dummycloud.conf
    dos2unix $DUMMYCLOUD_PATH/doc/etc_hosts-snippet.txt
    dos2unix $DUMMYCLOUD_PATH/doc/etc_rc.local-snippet.txt

    install -m 0755 $DUMMYCLOUD_PATH/dummycloud $IMG_DIR/usr/local/bin/dummycloud
    install -m 0644 $DUMMYCLOUD_PATH/doc/dummycloud.conf $IMG_DIR/etc/init/dummycloud.conf

    cat $DUMMYCLOUD_PATH/doc/etc_hosts-snippet.txt >> $IMG_DIR/etc/hosts

    sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
    cat $DUMMYCLOUD_PATH/doc/etc_rc.local-snippet.txt >> $IMG_DIR/etc/rc.local
    echo >> $IMG_DIR/etc/rc.local
    echo "exit 0" >> $IMG_DIR/etc/rc.local

    # UPLOAD_METHOD   0:NO_UPLOAD    1:FTP    2:FDS
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Let the script cleanup logs
    sed -i 's/nice.*//' $IMG_DIR/opt/rockrobo/rrlog/tar_extra_file.sh

    # Disable collecting device info to /dev/shm/misc.log
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/misc.sh

    # Disable logging of 'top'
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/toprotation.sh
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/topstop.sh
fi

if [ $ENABLE_VALETUDO -eq 1 ]; then
    echo "Installing valetudo"

    install -m 0755 $VALETUDO_PATH/valetudo $IMG_DIR/usr/local/bin/valetudo
    install -m 0644 $VALETUDO_PATH/deployment/valetudo.conf $IMG_DIR/etc/init/valetudo.conf

    cat $VALETUDO_PATH/deployment/etc/hosts >> $IMG_DIR/etc/hosts

    sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
    cat $VALETUDO_PATH/deployment/etc/rc.local >> $IMG_DIR/etc/rc.local
    echo >> $IMG_DIR/etc/rc.local
    echo "exit 0" >> $IMG_DIR/etc/rc.local

    # UPLOAD_METHOD=2
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\12/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\12/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Set LOG_LEVEL=3
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Reduce logging of miio_client
    sed -i 's/-l 2/-l 0/' $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf

    # Let the script cleanup logs
    sed -i 's/nice.*//' $IMG_DIR/opt/rockrobo/rrlog/tar_extra_file.sh

    # Disable collecting device info to /dev/shm/misc.log
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/misc.sh

    # Disable logging of 'top'
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/toprotation.sh
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/topstop.sh
fi

if [ -n "$NTPSERVER" ]; then
    echo "$NTPSERVER" > $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
else
    echo "# you can add your server line by line" > $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
    echo "0.pool.ntp.org" >> $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
    echo "1.pool.ntp.org" >> $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
    echo "2.pool.ntp.org" >> $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
    echo "3.pool.ntp.org" >> $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
fi

echo "$TIMEZONE" > $IMG_DIR/etc/timezone

if [ -n "$SOUNDFILE_PATH" ]; then
    SND_DST_DIR="$IMG_DIR/opt/rockrobo/resources/sounds/${SOUNDLANG}"
    install -d -m 0755 $SND_DST_DIR

    # Add sounds for a specific language
    for f in ${SND_DIR}/*.wav; do
        install -m 0644 $f ${SND_DST_DIR}/$(basename ${f})
    done
fi

i=0
while true; do
    ret=0
    umount $IMG_DIR || ret=$?
    # needed when mounted via fuse or guestmount
    echo "waiting for unmount..."
    sleep 2
    if [ "$ret" -eq 0 ]; then
        break
    fi
    i=$((i+1))
    if [ $i -ge 10 ]; then
        break
    fi
done

if [ $i -eq 10 ]; then
    echo "tried to umount 10 times and failed"
    exit 1
fi

echo "Pack new firmware"
PATCHED="$FW_DIR/${FIRMWARE_FILENAME}_patched.pkg"
tar -C "$FW_DIR" -czf "$PATCHED" disk.img
if [ ! -r "$PATCHED" ]; then
    echo "File $PATCHED not found! Packing the firmware was unsuccessful."
    exit 1
fi

echo "Encrypt firmware"
$CCRYPT -e -K "$PASSWORD_FW" "$PATCHED"

echo "Copy firmware to output/${FIRMWARE_BASENAME} and creating checksums"
install -d -m 0755 output
install -m 0644 "${PATCHED}.cpt" "output/${FIRMWARE_BASENAME}"

if [ "$IS_MAC" = true ]; then
    md5 "output/${FIRMWARE_BASENAME}" > "output/${FIRMWARE_FILENAME}.md5"
else
    md5sum "output/${FIRMWARE_BASENAME}" > "output/${FIRMWARE_FILENAME}.md5"
fi
chmod 0644 "output/${FIRMWARE_FILENAME}.md5"

echo "FINISHED"
cat "output/${FIRMWARE_FILENAME}.md5"
exit 0
