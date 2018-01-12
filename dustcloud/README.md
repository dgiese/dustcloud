Highly experimental software!
do not use for production or reachable from the internet;)

Contains known SQL injection vulnerability, which will be fixed soon.
This tool is intended for reverse engineering of the cloud protocol.

Todo: Replace SQL Queries with prepared statements.

## Requirements
- MySQL/MariaDB Database server
- Webserver with PHP
- Python3
- python-miio

## Installation (Server)

1. copy www subfolder to webserver directory (e.g. /var/www)
2. create new user + database for dustcloud (e.g. Databasename dustcloud)
3. import dustcloud.sql into database
4. edit this line in server.py with your DB credentials
  > 	self.db = pymysql.connect("localhost","dustcloud","","dustcloud")

  should be:

  > 	self.db = pymysql.connect("localhost","###dbusername###","###dbpassword###","###dbname###")
5. change this line in server.py with your public or routed ip address of the server (must be outside the local /24 network)

  > myCloudserverIP = "10.0.0.1"

6. rename www/config.php.dist to www/config.php
7. set DB credentials in www/config.php
8. add your device to the database

  minimal required information: DID (integer), enckey (16 Byte String) (you find both in /mnt/default/device.conf)
  
  open index.php and click on new device.
  
9. change entries for ot.io.mi.com + ott.io.mi.com in /etc/hosts on vacuum robot to your "myCloudserverIP" (see point #5)

## Install commands for Raspberry Pi

1. See https://github.com/dgiese/dustcloud/blob/master/dustcloud/raspberrypi_installcommands.txt)
> Change IP 123.123.123.123 to your server IP
2. Open http://#yourserveripaddress#:81/dustcloud/index.php
3. Add DID and Enckey (from device.conf on vacuum)
4. change entries for ot.io.mi.com + ott.io.mi.com in /etc/hosts on vacuum robot to your "myCloudserverIP"
5. start server.py by running server.sh