Welcome to our repository for hacking and rooting of the Xiaomi Smart Home Devices. We provide you methods how to root your device without opening it or breaking the warranty seal (on your own risk).

You can find a step-by-step guide how to wirelessly root your vacuum robot [here](https://github.com/dgiese/dustcloud/blob/master/devices/xiaomi.vacuum/UPDATE-howto.md).

The 

# Talks

Recording of our talk at 34C3 (2017): https://media.ccc.de/v/34c3-9147-unleash_your_smart-home_devices_vacuum_cleaning_robot_hacking

You can find a more detailed version of our 34c3 presentation with more details [here](https://github.com/dgiese/dustcloud/raw/master/34c3-presentation/presentations/34c3-2017/34c3_Staubi-current_split_animation.pdf).


We had a talk at Recon BRX 2018, the recording should be published in the next few months: (https://recon.cx/2018/brussels/)

The Recon presentation can be found [here](https://github.com/dgiese/dustcloud/raw/master/34c3-presentation/presentations/Recon-BRX2018/recon_brx_2018-final-split.pdf)

# Recommended ressources / links

Flole App: alternative way to control the vacuum robot, instead of Xiaomi's Mi Home App. Is able to control and root your vacuum cleaner.
https://xiaomi.flole.de/

Roboter-Forum.com: German speaking forum with a lot of information about all sorts of robots. Contains special subforums for Xiaomi rooting. Primary ressource for beginners.
[http://www.roboter-forum.com/](http://www.roboter-forum.com/showthread.php?25097-Root-Zugriff-auf-Xiaomi-Mi-Vacuum-Robot)

## FAQ
### Can you hack all Xiaomi vacuum cleaners connected to the internet?
No, you can root only your own device, devices which are in your own wifi or where you have physical access to (at least for now).
### Do Xiaomi know the exact position of the vacuum (e.g. address)?
Yes. The devices transfer its connected SSID, the gateway's MAC address and the RSS value every 30 minutes to the cloud. Theoretically you can pinpoint a address very precisely with that information, e.g. by using Google's geolocation API.
In addition to that your smartphone transfers its exact position while pairing/provisioning the device with the cloud. The cloud stores that position with the devices dataset.
### Is Dustcloud breaking the HTTPS connection / any SSL connection?
No, dustcloud requires the symmetric key (e.g. extracted from /mnt/default/device.conf) to decrypt the AES connection to the cloud. The same key is used to encrypt the forwarded messages to the cloud.
Note: I personally think that Xiaomis approach of device's unique AES key solves a lot of cloud problems: authentication, integrity and confidentiality.
### Will you publish rooting methods for other devices?
There are plans for that. But keep in mind that the devices were financed from my private budget, therefore the focus will be on devices that i will use myself after the hacking. Do not expect a smart fridge (i have a stupid one already) or a smart car (too expensive). However if you have broken devices (like a used Air purifier or something) or spare devices you want to get rid of, you can contact me. I might be interested in some PCBs ;)
### Is there a communication way for the community to exchange ideas?
Yes, there is a telegram channel. https://t.me/joinchat/Fl7MmxBwXWC7ETNZAXQLSQ

Please inform yourself in the forums and with the howtos before you post in this channel. Otherwise your message is very likely to be ignored.

# Contact
* Dennis Giese <dgi[at]posteo.de>
* Daniel Wegemer <daniel[at]wegemer.com>

# Press information

Iot will very likely become a very important topic in the future. 
If you like to know more about IoT security, you can visit us at Northeastern University in Boston, US (Dennis) or at the TU Darmstadt, DE. Please contact us.

# Acknowledgements:
### Prof. Matthias Hollick at Secure Mobile Networking Lab (SEEMOO)
<a href="https://www.seemoo.tu-darmstadt.de">![SEEMOO logo](https://github.com/dgiese/dustcloud/raw/master/gfx/seemoo.png)</a>
### Prof. Guevara Noubir (CCIS, Northeastern University)
<a href="http://www.ccs.neu.edu/home/noubir/Home.html">![CCIS logo](https://github.com/dgiese/dustcloud/raw/master/gfx/CCISLogo_S_gR.png)</a>
# Media coverage:
* https://www.kaspersky.com/blog/xiaomi-mi-robot-hacked/12567/
* https://www.golem.de/news/xiaomi-mit-einem-stueck-alufolie-autonome-staubsauger-rooten-1712-131883.html
* http://www.zeit.de/digital/datenschutz/2017-12/34c3-hack-staubsauger-iot
* https://hackaday.com/2017/12/27/34c3-the-first-day-is-a-doozy/
* https://m.heise.de/newsticker/meldung/34C3-Vernetzter-Staubsauger-Roboter-aus-China-gehackt-3928360.html
* https://www.notebookcheck.com/Security-Staubsauger-sammelt-neben-Staub-auch-Daten-ueber-die-Wohnung.275668.0.html
* https://derstandard.at/2000071134392/Sicherheitsforscher-hacken-Staubsaugerroboter-und-finden-Bedenkliches (at some points very inaccurate)
