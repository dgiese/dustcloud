Preparation
- install python-mirobo (python3!)
- Create custom image with imagebuilder.sh, Copy MD5 sum
+ you need to create your own ssh keypair and create an authorized key file
+ pack english.pkg and v11_xxxxxx.pkg into folder of the imagebuilder.sh
+ image builder needs to be as root (need to mount image)
- Install local webserver and place created image into htdocs (do not change filename, it must have the format v11_xxxxxx.pkg)
+ You may use also the integrated Python3-HTTP-Server
- Connect the vacuum robot to the charging station

1) Put vacuum robot in unprovisioned mode (press WiFi button)
2) Connect to open WiFi
+ Do not connect to any other network (e.g. LAN)
3) # mirobo discover --handshake true
4) # mirobo --ip=192.168.8.1 --token=#Token_from_above# status
	-> should return status
5) # mirobo --ip=192.168.8.1 --token=#Token_from_above# raw_command miIO.ota '{"mode":"normal", "install":"1", "app_url":"https://#ipaddress-of-your-computer#/v11_#version#.pkg", "file_md5":"#md5#","proc":"dnld install"}'
+ Check status with command from 4)
+ Wait 10 minutes (you should see an access on your http server)
6) If update is complete: try ssh access on 192.168.8.1 with user root
