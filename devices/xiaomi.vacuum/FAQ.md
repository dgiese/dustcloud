### Is it required to open the robot / break the warranty seals to root it?
No, you can push the firmwareupdate to the robot without opening it. See the Update howto.
### Does the root of Gen1 also work for Gen2 (aka Roborock S50)?
Yes, however you need to use the firmware of Gen2 for the rooting. Do not flash Gen1 firmware on a Gen2 device and vice versa.
### Whats the difference between CN Gen2 and EU Gen2 (aka international versison)?
Technically there is none. The only difference are the manuals and labels in chinese language, the chinese powercord and one configuration file. You can easily apply the european configuration to your CN version. There is a tool for that in the Gen2 folder in this repository.
### Why there is still no custom patched firmware available (with SSH)?
While you can build your own firmware with SSH, we are not sure if we want to provide a pre-rooted version with some default SSH keys. As we know you (and us) some people might not change the keys afterwards. So instead of giving just you access to the vacuum, other people would have also access to your vacuum. We would like to make the world safer and not more vulnerable. Therefore we are thinking of some solution for that.
### Can i use the vacuum without connecting to any Wifi?
Sure, however set a password to protect the Wifi AP of your vacuum robot. Edit the file /opt/rockrobo/wlan/wifi_start.sh and change this:

CMD="create_ap -c $channel -n wlan0 -g 192.168.8.1 $ssid_ap --daemon" 

to 

CMD="create_ap -c $channel -n wlan0 -g 192.168.8.1 $ssid_ap YourWPApassword --daemon". 

Then your unprovisioned vacuum has a protected Wifi and you are still able to connect (if you do not lose the password).
### Is there a risk that Xiaomi do a force update and disable the root?
Technically there is, but i do not believe so. In any case you can disable updates (yours and Xiaomi's) by renaming the ccrypt command. 
See [disable-UPDATES.md](https://github.com/dgiese/dustcloud/blob/master/devices/xiaomi.vacuum/disable-UPDATES.md) for additional information. 
