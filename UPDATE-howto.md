## Preparation
1. Install [python-miio](https://github.com/rytilahti/python-miio) (python3!)
1. Install ccrypt(apt-get install ccrypt)
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


### Instructions on Mac OS
1. Install [homebrew package manager](https://brew.sh/)
1. Install python3: `brew install python3`
1. Install a python3 package manager like [pipenv](http://docs.python-guide.org/en/latest/dev/virtualenvs/): `python3 pip install- -user pipenv`
	 * You need to add the python3 installation to your system's PATH like it is recommended on the pipenv page
	 * e.g. `export PATH=$PATH:/Users/<yourUsername>/Library/Python/3.6/bin`
	 * set correct locales for pipenv, e.g. ```export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8```
1. Install [python-miio](https://github.com/rytilahti/python-miio) by going to the project folder of this repo and type `pipenv install requests` which will install all necessary requirements for python3. python-mirobo is outdated and isn't updated anymore.
1. Install ccrypt: `brew install ccrypt`
1. Create a ssh keypair: `ssh-keygen -f ~/.ssh/id_rsa_xiaomi`
1. Create an `authorized_keys` file and place the content of ~/.ssh/id_rsa_xiaomi.pub in there: `cat ~/.ssh/id_rsa_xiaomi.pub > <this-repo-path>/xiaomi.vacuum.gen1/firmwarebuilder/authorized_keys`
1. Make the imagebuilder.sh script executable: `chmod +x <this-repo-path>/xiomi.vacuum.gen1/firmwarebuilder/imagebuilder.sh`
1. Install fuse and ext4 support to open the firmware images
	* `brew cask install osxfuse`
	* `brew install m4 autoconf automake libtool e2fsprogs`
	* follow [these instructions](https://docs.j7k6.org/mount-ext4-macos/).
	* `brew install ext4fuse`
	* The first time you'll mount an ext4 fs with fuse, it will prompt you to allow the extension (at least on High Sierra). Allow and retry the script, otherwise you'll need to use a Linux VM
1. execute `xiomi.vacuum.gen1/firmwarebuilder/imagebuilder.sh` with a version number. The version number must be the same as the fw image you've copied to the folder. e.g. `./imagebuilder.sh 003094`
1. note the returned MD5 sum. You can see the md5 sum also in the output folder under v11_xxxxxx.md5
1. execute `pipenv shell` from the repo root folder to enable support for python-mirobo
1. Put vacuum robot in unprovisioned mode (Reset Wifi by pressing Power and Dock button for a few seconds until you hear "resetting WiFi")
1. Connect to open WiFi of the robot(rockrobo-XXXX)
	* Do not connect to any other network (e.g. LAN)
1. Execute `mirobo discover --handshake true` and note the returned token 
1. Execute `mirobo --ip=192.168.8.1 --token=#Token_from_above# status`
	* should return status
1. Execute `mirobo --ip=192.168.8.1 --token=#Token_from_above# raw_command miIO.ota '{"mode":"normal", "install":"1", "app_url":"http://#ipaddress-of-your-computer#/v11_#version#.pkg", "file_md5":"#md5#","proc":"dnld install"}'`
	* replace ipaddress, version and md5 with your data
	* Check status with command from 4)
	* Wait 10 minutes (you should see an access on your http server)
1. If update is complete: try ssh access on 192.168.8.1 with user root
