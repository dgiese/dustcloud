## Preparation
1. Install [python-mirobo](https://github.com/ultrara1n/python-mirobo) (python3!)
1. Create custom image with imagebuilder.sh, Copy MD5 sum
	* you need to create your own ssh keypair and create an authorized key file
		* for Windows you might use PuttyGen to create the keypair
	* copy english.pkg and v11_xxxxxx.pkg into folder of the imagebuilder.sh
	* image builder needs to be as root (need to mount image)
		* if you use Windows: you need to run it in a Linux VM
1. Install local webserver and place created image into htdocs
	* do not change filename, it must have the format v11_xxxxxx.pkg
	* You may use also the integrated Python3-HTTP-Server
1. Connect the vacuum robot to the charging station

## Update
1. Put vacuum robot in unprovisioned mode (press WiFi button)
1. Connect to open WiFi of the robot(rockrobo-XXXX)
	* Do not connect to any other network (e.g. LAN)
1. > mirobo discover --handshake true
1. > mirobo --ip=192.168.8.1 --token=#Token_from_above# status
	-> should return status
1. > mirobo --ip=192.168.8.1 --token=#Token_from_above# raw_command miIO.ota '{"mode":"normal", "install":"1", "app_url":"http://#ipaddress-of-your-computer#/v11_#version#.pkg", "file_md5":"#md5#","proc":"dnld install"}'
	* replace ipaddress, version and md5 with your data
	* Check status with command from 4)
	* Wait 10 minutes (you should see an access on your http server)
1. If update is complete: try ssh access on 192.168.8.1 with user root
