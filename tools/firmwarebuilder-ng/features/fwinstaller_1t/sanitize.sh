rm ./squashfs-root/etc/OTA_Key_pub.pem
rm ./squashfs-root/etc/adb_keys
rm ./squashfs-root/etc/publickey.pem
rm ./squashfs-root/usr/bin/autossh.sh
rm ./squashfs-root/usr/bin/backup_key.sh
rm ./squashfs-root/usr/bin/curl_download.sh
rm ./squashfs-root/usr/bin/curl_upload.sh
rm ./squashfs-root/usr/bin/packlog.sh
sed -i "s/dibEPK917k/Gi29djChze/" ./squashfs-root/etc/*