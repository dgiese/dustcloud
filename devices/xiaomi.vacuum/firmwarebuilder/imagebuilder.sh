#!/bin/bash
# Author: Dennis Giese [dustcloud@1338-1.org]
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

function cleanup_and_exit ()
{
    if test "$1" = 0 -o -z "$1" ; then
        exit 0
    else
        exit $1
    fi
}

print_help()
{
    cat << EOF
usage: sudo ./imagebuilder.sh -f v11_003194.pkg [-s english.pkg] [-k id_rsa.pub ] [ -t Europe/Berlin ] [--disable-xiaomi]

Options:
  -f, --firmware            path to firmware file
  -s, --soundfile           path to sound file
  -k, --public-key          path to ssh public key to be added to authorized_keys file
                            if need to add multiple keys set -k as many times as you need:
                            -k ./local_key.pub -k ~/.ssh/id_rsa.pub -k /root/ssh/id_rsa.pub
  -t, --timezone            timezone to be used in vacuum
  --disable-xiaomi          disable xiaomi servers using hosts file
  --dummycloud-path PATH    Provide the path to dummycloud
  --adbd                    replace xiaomis custom adbd with generic adbd version
  --patch-rrlogd            patch rrlogd to disable log encryption
  --disable-logs            disables most log files creations and log uploads on the vacuum
  --ruby                    restores user ruby (can do sudo) and assigns a random password
  --unprovisioned           Access your network in unprovisioned mode (currently only wpa2psk is supported)
                            --unprovisioned wpa2psk
                            --ssid YOUR_SSID
                            --psk YOUR_WIRELESS_PASSWORD
  -h, --help                prints this message

Each parameter that takes a file as an argument accepts path in any form

Report bugs to: https://github.com/dgiese/dustcloud/issues
EOF
}

if [[ $# -eq 0 ]]; then
    print_help
    exit 0
fi

# Check if we have GNU readlink
# see https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
readlink -f imagebuilder.sh 2> /dev/null
if [ $? -eq 0 ]; then
    echo "Compatible readlink found!"
else
    echo "readlink from coreutils package not found! Please install it first (e.g. by brew install coreutils)"
    exit 1
fi

PUBLIC_KEYS=()
RESTORE_RUBY=false
PATCH_ADBD=false
DISABLE_XIAOMI=false
UNPROVISIONED=false
DISABLE_LOGS=false
ENABLE_DUMMYCLOUD=false
PATCH_RRLOGD=false
while [[ $# -gt 0 ]]; do
key="$1"

case $key in
    -f|--firmware)
    FIRMWARE="$2"
    shift
    shift
    ;;
    -s|--soundfile)
    SOUNDFILE_PATH="$2"
    shift
    shift
    ;;
    -k|--public-key)
    if [ -f "$2" ]; then
        PUBLIC_KEYS[${#PUBLIC_KEYS[*]} + 1]=$(readlink -f "$2")
    else
        echo "File $2 not found!"
        exit 1
    fi
    shift
    shift
    ;;
    -t|--timezone)
    TIMEZONE="$2"
    shift
    shift
    ;;
    --disable-xiaomi)
    DISABLE_XIAOMI=true
    shift
    ;;
    --disable-logs)
    DISABLE_LOGS=true
    shift
    ;;
    --adbd)
    PATCH_ADBD=true
    shift
    ;;
    --patch-rrlogd)
    PATCH_RRLOGD=true
    shift
    ;;
    --ruby)
    RESTORE_RUBY=true
    shift
    ;;
    --dummycloud-path)
    DUMMYCLOUD_PATH=$2
    if [ -r $DUMMYCLOUD_PATH/dummycloud ]; then
        ENABLE_DUMMYCLOUD=true
    else
        echo "dummycloud binary not found! Please download it from https://github.com/dgiese/dustcloud"
        exit 1
    fi
    shift
    ;;
    --unprovisioned)
    UNPROVISIONED=true
    WIFIMODE="$2"
    shift
    ;;
    --ssid)
    SSID="$2"
    shift
    ;;
    --psk)
    PSK="$2"
    shift
    ;;
    -h|--help)
    print_help
    exit 0
    ;;
    *)
    shift
    ;;
esac
done

SCRIPT="$0"
SCRIPTDIR=$(dirname "${0}")
COUNT=0
while [ -L "${SCRIPT}" ]
do
    SCRIPT=$(readlink ${SCRIPT})
    COUNT=$(expr ${COUNT} + 1)
    if [ ${COUNT} -gt 100 ]
    then
        echo "Too many symbolic links"
        exit 1
    fi
done
BASEDIR=$(dirname "${SCRIPT}")
echo "Script path: $BASEDIR"

if [ $EUID -ne 0 ]; then
    echo "You need root privileges to execute this script"
    exit 1
fi

IS_MAC=false
if [[ $OSTYPE == darwin* ]]; then
    # Mac OSX
    IS_MAC=true
    echo "Running on a Mac, adjusting commands accordingly"
fi

CCRYPT="$(type -p ccrypt)"
if [ ! -x "$CCRYPT" ]; then
    echo "ccrypt not found! Please install it (e.g. by (apt|brew|dnf|zypper) install ccrypt)"
    cleanup_and_exit 1
fi

if [ ${#PUBLIC_KEYS[*]} -eq 0 ]; then
    echo "No public keys selected!"
    exit 1
fi

SOUNDFILE_PATH=${SOUNDFILE_PATH:-"english.pkg"}
TIMEZONE=${TIMEZONE:-"Europe/Berlin"}
PASSWORD_FW="rockrobo"
PASSWORD_SND="r0ckrobo#23456"

if [ ! -r "$FIRMWARE" ]; then
    echo "You need to specify an existing firmware file, e.g. v11_003194.pkg"
    exit 1
fi
FIRMWARE=$(readlink -f "$FIRMWARE")
FIRMWARE_BASENAME=$(basename $FIRMWARE)
FIRMWARE_FILENAME="${FIRMWARE_BASENAME%.*}"

if [ ! -r "$SOUNDFILE_PATH" ]; then
    echo "Sound file $SOUNDFILE_PATH not found!"
    exit 1
fi
SOUNDFILE_PATH=$(readlink -f "$SOUNDFILE_PATH")

if [ "$PATCH_ADBD" = true ]; then
    if [ ! -f ./adbd ]; then
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

echo "Decrypt soundfile .."
SND_DIR="$FW_TMPDIR/sounds"
SND_FILE=$(basename $SOUNDFILE_PATH)
mkdir -p $SND_DIR
cp "$SOUNDFILE_PATH" "$SND_DIR/$SND_FILE"
$CCRYPT -d -K "$PASSWORD_SND" "$SND_DIR/$SND_FILE"

echo "Unpack soundfile .."
pushd "$SND_DIR"
tar -xzf "$SND_FILE"
popd

echo "Decrypt firmware"
FW_DIR="$FW_TMPDIR/fw"
mkdir -p "$FW_DIR"
cp "$FIRMWARE" "$FW_DIR/$FIRMWARE_FILENAME"
$CCRYPT -d -K "$PASSWORD_FW" "$FW_DIR/$FIRMWARE_FILENAME"

echo "Unpack firmware"
pushd "$FW_DIR"
tar -xzf "$FIRMWARE_FILENAME"
if [ ! -r disk.img ]; then
    echo "File disk.img not found! Decryption and unpacking was apparently unsuccessful."
    exit 1
fi
popd

IMG_DIR="$FW_TMPDIR/image"
mkdir -p "$IMG_DIR"

if [ "$IS_MAC" = true ]; then
    #ext4fuse doesn't support write properly
    #ext4fuse disk.img image -o force
    fuse-ext2 "$FW_DIR/disk.img" "$IMG_DIR" -o rw+
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
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf

echo "Add SSH authorized_keys"
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh

if [ -r $IMG_DIR/root/.ssh/authorized_keys ]; then
    echo "Removing obsolete authorized_keys from Xiaomi image"
    rm $IMG_DIR/root/.ssh/authorized_keys
fi

for i in $(eval echo {1..${#PUBLIC_KEYS[*]}}); do
    cat "${PUBLIC_KEYS[$i]}" >> $IMG_DIR/root/.ssh/authorized_keys
done
chmod 600 $IMG_DIR/root/.ssh/authorized_keys

if [ "$DISABLE_XIAOMI" = true ]; then
    echo "reconfiguring network traffic to xiaomi"
    # comment out this section if you do not want do disable the xiaomi cloud
    # or redirect it
    echo "0.0.0.0       awsbj0-files.fds.api.xiaomi.com" >> $IMG_DIR/etc/hosts
    echo "0.0.0.0       awsbj0.fds.api.xiaomi.com" >> $IMG_DIR/etc/hosts
    #echo "0.0.0.0       ott.io.mi.com" >> ./etc/hosts
    #echo "0.0.0.0       ot.io.mi.com" >> ./etc/hosts
fi
if [ "$UNPROVISIONED" = true ]; then
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
        cp $BASEDIR/unprovisioned/start_wifi.sh $IMG_DIR/opt/unprovisioned
        chmod +x ./opt/unprovisioned/start_wifi.sh

        sed -i 's/exit 0//' $IMG_DIR/etc/rc.local
        cat $BASEDIR/unprovisioned/rc.local >> $IMG_DIR/etc/rc.local
        echo "exit 0" >> $IMG_DIR/etc/rc.local

        cp $BASEDIR/unprovisioned/wpa_supplicant.conf.wpa2psk $IMG_DIR/opt/unprovisioned/wpa_supplicant.conf

        sed -i 's/#SSID#/'"$SSID"'/g' $IMG_DIR/opt/unprovisioned/wpa_supplicant.conf
        sed -i 's/#PSK#/'"$PSK"'/g'   $IMG_DIR/opt/unprovisioned/wpa_supplicant.conf
    fi
fi

if [ "$PATCH_ADBD" = true ]; then
    echo "replacing adbd"
    cp $IMG_DIR/usr/bin/adbd $IMG_DIR/usr/bin/adbd.xiaomi
    cp $BASEDIR/adbd $IMG_DIR/usr/bin/adbd
fi

if [ "$DISABLE_LOGS" = true ]; then
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

if [ "$PATCH_RRLOGD" = true ]; then
    bspatch=$(type -p bspatch)

    if [ -n "$bspatch" ]; then
        echo "checking if we can patch rrlogd"

        rrlog_md5sum=$(md5sum $IMG_DIR/opt/rockrobo/rrlog/rrlogd | cut -d ' ' -f 1)
        rrlog_patch="$BASEDIR/../rrlog/$rrlog_md5sum/rrlogd.binarypatch"

        if [ -r "$rrlog_patch" ]; then
            echo "creating backup of rrlogd"
            cp $IMG_DIR/opt/rockrobo/rrlog/rrlogd $IMG_DIR/opt/rockrobo/rrlog/rrlogd.xiaomi

            echo "patching rrlogd ($rrlog_md5sum)"
            $bspatch \
                $IMG_DIR/opt/rockrobo/rrlog/rrlogd.xiaomi \
                $IMG_DIR/opt/rockrobo/rrlog/rrlogd \
                $rrlog_patch || echo "ERROR: patching rrlogd failed!"
        fi
    fi
fi

if [ "$RESTORE_RUBY" = true ]; then
    echo "Generate random password for user ruby"
    USER_PASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};echo;`
    #original password (<=v3254) file has the following credentials:
    #   root:rockrobo
    #   ruby:rockrobo
    echo "Restore old usertable to enable user ruby"
    cp $IMG_DIR/etc/passwd- $IMG_DIR/etc/passwd
    cp $IMG_DIR/etc/group-  $IMG_DIR/etc/group
    cp $IMG_DIR/etc/shadow- $IMG_DIR/etc/shadow
    #cp ./etc/gshadow- ./etc/gshadow
    #cp ./etc/subuid- ./etc/subuid
    #cp ./etc/subgid- ./etc/subgid
    #if this fails, then the password is rockrobo for user ruby
    echo "ruby:$USER_PASSWORD" | chpasswd -c SHA512 -R $PWD
    echo $USER_PASSWORD > "output/${FIRMWARE_FILENAME}.password"
    ###
fi

if [ "$ENABLE_DUMMYCLOUD" = true ]; then
    echo "Installing dummycloud"

    cp $DUMMYCLOUD_PATH/dummycloud $IMG_DIR/usr/local/bin/dummycloud
    chmod 0755 $IMG_DIR/usr/local/bin/dummycloud
    cp $DUMMYCLOUD_PATH/doc/dummycloud.conf $IMG_DIR/etc/init/dummycloud.conf

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

echo "#you can add your server line by line" > $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
echo "0.de.pool.ntp.org" >> $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
echo "1.de.pool.ntp.org" >> $IMG_DIR/opt/rockrobo/watchdog/ntpserver.conf
echo "$TIMEZONE" > $IMG_DIR/etc/timezone
# Replace chinese soundfiles with english soundfiles
cp -f $SND_DIR/*.wav $IMG_DIR/opt/rockrobo/resources/sounds/prc/

while [ $(umount $IMG_DIR; echo $?) -ne 0 ]; do
    echo "waiting for unmount..."
    sleep 2
done

echo "Pack new firmware"
pushd $FW_DIR
PATCHED="${FIRMWARE_FILENAME}_patched.pkg"
tar -czf "$PATCHED" $FW_DIR/disk.img
if [ ! -r "$PATCHED" ]; then
    echo "File $PATCHED not found! Packing the firmware was unsuccessful."
    exit 1
fi

echo "Encrypt firmware"
$CCRYPT -e -K "$PASSWORD_FW" "$PATCHED"
popd

echo "Copy firmware to output/${FIRMWARE_BASENAME} and creating checksums"
mkdir -p output
mv "$FW_DIR/${PATCHED}.cpt" "output/${FIRMWARE_BASENAME}"

if [ "$IS_MAC" = true ]; then
    md5 "output/${FIRMWARE_BASENAME}" > "output/${FIRMWARE_FILENAME}.md5"
else
    md5sum "output/${FIRMWARE_BASENAME}" > "output/${FIRMWARE_FILENAME}.md5"
fi

echo "Cleaning up"
rm -rf $FW_TMPDIR

echo "FINISHED"
cat "output/${FIRMWARE_FILENAME}.md5"
exit 0
