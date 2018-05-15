#!/bin/bash

# Set LOG_LEVEL=3
sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' /opt/rockrobo/rrlog/rrlog.conf
sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' /opt/rockrobo/rrlog/rrlogmt.conf

#UPLOAD_METHOD=0
sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' /opt/rockrobo/rrlog/rrlog.conf

#UPLOAD_METHOD=0
sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' /opt/rockrobo/rrlog/rrlog.conf

# Add exit 0
sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/misc.sh
sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/tar_extra_file.sh
sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/toprotation.sh
sed -i '/^\#!\/bin\/bash$/a exit 0' /opt/rockrobo/rrlog/topstop.sh

# Comment $IncludeConfig
service rsyslog stop
sed -Ei 's/^(\$IncludeConfig)/#&/' /etc/rsyslog.conf
service rsyslog start

