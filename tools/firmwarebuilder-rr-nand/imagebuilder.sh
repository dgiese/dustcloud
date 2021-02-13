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

# set -eu

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
echo "Usage: sudo $(basename $0) --firmware=firmware.zip [--public-key=id_rsa.pub|--timezone=Europe/Berlin|--valetudo|--help]"
}

print_help()
{
    cat << EOF

Options:
  -f, --firmware=PATH        Path to decrypted firmware file
  -k, --public-key=PATH      Path to ssh public key to be added to authorized_keys file
                             if need to add multiple keys set -k as many times as you need:
                             -k ./local_key.pub -k ~/.ssh/id_rsa.pub -k /root/ssh/id_rsa.pub
  -t, --timezone             Timezone to be used in vacuum
  --valetudo                 Prepare valetudo installation in the firmware (disables cloud)
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
ENABLE_VALETUDO=0

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
        *-hostname)
            CUSTOM_HOSTNAME="$ARG"
            shift
            ;;
        *-valetudo)
            ENABLE_VALETUDO=1
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

IS_MAC=false
case $(uname | tr '[:upper:]' '[:lower:]') in
  darwin*)
    # Mac OSX
    IS_MAC=true
    echo "Execution on MAC is not tested at the moment. Exiting to protect your robot from being a brick."
    exit 1
    ;;
  *)
    ;;
esac

DROPBEARKEY="$(command -v dropbearkey)"
if [ ! -x "$DROPBEARKEY" ]; then
    echo "dropbearkey not found! Please install it (e.g. by (apt|brew|dnf|zypper) install dropbear)"
    exit 1
fi

UNZIP="$(command -v unzip)"
if [ ! -x "$UNZIP" ]; then
    echo "unzip not found! Please install it "
    exit 1
fi

UNSQUASHFS="$(command -v unsquashfs)"
if [ ! -x "$UNSQUASHFS" ]; then
    echo "unsquashfs not found! Please install it "
    exit 1
fi

MKSQUASHFS="$(command -v mksquashfs)"
if [ ! -x "$MKSQUASHFS" ]; then
    echo "mksquashfs not found! Please install it "
    exit 1
fi

if [ -z "$PUBLIC_KEYS" ]; then
    echo "No public keys selected!"
    exit 1
fi

TIMEZONE=${TIMEZONE:-"Europe/Berlin"}

if [ ! -r "$FIRMWARE_PATH" ]; then
    echo "You need to specify an existing firmware file, e.g. firmware.zip"
    exit 1
fi

FIRMWARE_PATH=$(readlink_f "$FIRMWARE_PATH")
FIRMWARE_BASENAME=$(basename $FIRMWARE_PATH)
FIRMWARE_FILENAME="${FIRMWARE_BASENAME%.*}"

if [ ! -f $SCRIPTDIR/files/adbd ]; then
    echo "File adbd not found, cannot replace adbd in image!"
    exit 1
fi

if [ ! -f $SCRIPTDIR/files/dropbear ]; then
    echo "File dropbear not found, cannot replace dropbear in image!"
    exit 1
fi

if [ ! -f $SCRIPTDIR/files/dbclient ]; then
    echo "File dropbear not found, cannot replace dropbear in image!"
    exit 1
fi


if [ ! -f $SCRIPTDIR/files/dropbearkey ]; then
    echo "File dropbear not found, cannot replace dropbear in image!"
    exit 1
fi

if [ ! -f $SCRIPTDIR/files/scp ]; then
    echo "File dropbear not found, cannot replace dropbear in image!"
    exit 1
fi

# Generate SSH Host Keys
echo "Generate SSH Host Keys if necessary"

if [ ! -r dropbear_rsa_host_key ]; then
    dropbearkey -t rsa -f dropbear_rsa_host_key
fi
if [ ! -r dropbear_dss_host_key ]; then
    dropbearkey -t dss -f dropbear_dss_host_key
fi
if [ ! -r dropbear_ecdsa_host_key ]; then
    dropbearkey -t ecdsa -f dropbear_ecdsa_host_key
fi
if [ ! -r dropbear_ed25519_host_key ]; then
    dropbearkey -t ed25519 -f dropbear_ed25519_host_key
fi

FW_TMPDIR="$(pwd)/$(mktemp -d fw.XXXXXX)"

echo "Unpack firmware"
FW_DIR="$FW_TMPDIR/fw"
mkdir -p "$FW_DIR"
cp "$FIRMWARE_PATH" "$FW_DIR/$FIRMWARE_FILENAME"
unzip "$FW_DIR/$FIRMWARE_FILENAME" -d "$FW_DIR"
mv "$FW_DIR/rootfs.img" "$FW_DIR/rootfs.img.template"
unsquashfs -d "$FW_DIR/squashfs-root" "$FW_DIR/rootfs.img.template" 
rm "$FW_DIR/rootfs.img.template"

if [ ! -r "$FW_DIR/squashfs-root/etc/inittab" ]; then
    echo "File $FW_DIR/squashfs-root/etc/inittab not found! Unpacking was apparently unsuccessful."
    exit 1
fi

IMG_DIR="$FW_DIR/squashfs-root"

echo "Replace ssh host keys"
cat dropbear_rsa_host_key > $IMG_DIR/etc/dropbear/dropbear_rsa_host_key
cat dropbear_dss_host_key > $IMG_DIR/etc/dropbear/dropbear_dss_host_key
cat dropbear_ecdsa_host_key > $IMG_DIR/etc/dropbear/dropbear_ecdsa_host_key
cat dropbear_ed25519_host_key > $IMG_DIR/etc/dropbear/dropbear_ed25519_host_key

echo "Disable SSH firewall rule"
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/rrlog/rrlogd

echo "Add SSH authorized_keys"
chown root:root $IMG_DIR/root
chmod 700 $IMG_DIR/root
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh

eval "set -- $PUBLIC_KEYS"
while [ -n "${1+x}" ]; do
    cat "$1" >> $IMG_DIR/root/.ssh/authorized_keys
    shift
done
chmod 600 $IMG_DIR/root/.ssh/authorized_keys

chown root:root $IMG_DIR/root -R


echo "replace dropbear"
install -m 0755 $BASEDIR/files/dropbear $IMG_DIR/usr/sbin/dropbear
install -m 0755 $BASEDIR/files/dbclient $IMG_DIR/usr/bin/dbclient
install -m 0755 $BASEDIR/files/dropbearkey $IMG_DIR/usr/bin/dropbearkey
install -m 0755 $BASEDIR/files/scp $IMG_DIR/usr/bin/scp


echo "replace adbd"
install -m 0755 $BASEDIR/files/adbd $IMG_DIR/usr/bin/adbd


echo "install iptables modules"
    mkdir -p $IMG_DIR/lib/xtables/
    tar -xzf $BASEDIR/files/xtables.tgz -C $IMG_DIR/lib/xtables/
    install -m 0755 $BASEDIR/files/ip6tables $IMG_DIR/sbin/ip6tables

echo "installing tools"
    tar -xzf $BASEDIR/files/tools.tgz -C $IMG_DIR/

echo "$TIMEZONE" > $IMG_DIR/etc/timezone


if [ $ENABLE_VALETUDO -eq 1 ]; then
    echo "Installing preparations for valetudo"

    # UPLOAD_METHOD=0 (no upload)
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

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
    
    # Disable cores
    sed -i -E 's/ulimit -c unlimited/ulimit -c 0/' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf

    echo "patching DNS"
    sed -i -E 's/110.43.0.83/127.000.0.1/g' $IMG_DIR/opt/rockrobo/miio/miio_client
    sed -i -E 's/110.43.0.85/127.000.0.1/g' $IMG_DIR/opt/rockrobo/miio/miio_client
    sed -i 's/dport 22/dport 27/' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
    cat $BASEDIR/files/hosts-local > $IMG_DIR/etc/hosts
fi

sed -i "s/^exit 0//" $IMG_DIR/etc/rc.local
echo "if [[ -f /mnt/reserve/_root.sh ]]; then" >> $IMG_DIR/etc/rc.local
echo "    /mnt/reserve/_root.sh &" >> $IMG_DIR/etc/rc.local
echo "fi" >> $IMG_DIR/etc/rc.local
echo "exit 0" >> $IMG_DIR/etc/rc.local

install -m 0755 $BASEDIR/files/S10rc_local_for_nand $IMG_DIR/etc/init/S10rc_local

install -m 0755 $BASEDIR/files/_root.sh.tpl $IMG_DIR/root/_root.sh.tpl
install -m 0755 $BASEDIR/files/how_to_modify.txt $IMG_DIR/root/how_to_modify.txt
touch $IMG_DIR/build.txt
echo "build with imagebuilder (https://builder.dontvacuum.me)" > $IMG_DIR/build.txt
echo $(date -u)  >> $IMG_DIR/build.txt
echo "" >> $IMG_DIR/build.txt

echo "finished patching, repacking"

cd ..

mksquashfs "$IMG_DIR/" "$FW_DIR/rootfs_tmp.img"
dd if="$FW_DIR/rootfs_tmp.img" of="$FW_DIR/rootfs.img" bs=128k conv=sync
rm "$FW_DIR/rootfs_tmp.img"
md5sum "$FW_DIR/*.img" > "$FW_DIR/firmware.md5sum"

echo "FINISHED"
cat "$FW_DIR/firmware.md5sum"
exit 0
