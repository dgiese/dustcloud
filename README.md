Welcome to our repository for hacking and rooting of the Xiaomi Vacuum Robot. We provide you methods how to root your device without opening it or breaking the warranty seal.

You can find a step-by-step guide how to wirelessly root your vacuum robot [here](https://github.com/dgiese/dustcloud/blob/master/UPDATE-howto.md).

Our presentation was designed for 35 minutes (+10 min FAQ) , however our available time was cut to 20 minutes(+10 min FAQ). Therefore we had to reduce the content in our presentation.
You can find a more detailed version of our 34c3 presentation with more details [here](https://github.com/dgiese/dustcloud/raw/master/34c3-presentation/34c3_Staubi-current_split_animation.pdf).
More technical information you find [here (techinfo.pdf)](https://github.com/dgiese/dustcloud/raw/master/xiaomi.vacuum.gen1/techinfo.pdf). The cloud protocol is described [here (cloudprotocol.pdf)](https://github.com/dgiese/dustcloud/raw/master/cloudprotocol.pdf)

Recording of our talk at 34C3: https://media.ccc.de/v/34c3-9147-unleash_your_smart-home_devices_vacuum_cleaning_robot_hacking

## FAQ
### Can you hack all Xiaomi vacuum cleaners connected to the internet?
No, you can root only your own device, devices which are in your own wifi or where you have physical access to.
### Do you consider the Xiaomi cloud as insecure?
Actually we think that Xiaomi did a good job in designing their cloud protocol (at least from a security perspective).
### Is it required to open the robot / break the warranty seals to root it?
No, you can push the firmwareupdate to the robot without opening it. See the Update howto.
### Do Xiaomi know the exact position of the vacuum (e.g. address)?
The vacuum transfers its connected SSID, the gateway's MAC address and the RSS value every 30 minutes to the cloud. Theoretically you can pinpoint a address very precisely with that information, e.g. by using Google's geolocation API.
### Does the root also work for Gen2?
There might be a way to root also Gen2. However as I (Dennis) do not have access to a Gen2 vacuum, i cannot give you more information on that. As soon as i will get my own Gen2 vacuum, i will update the information.
### Why there is still no custom patched firmware available (with SSH)?
While you can build your own firmware with SSH, we are not sure if we want to provide a pre-rooted version with some default SSH keys. As we know you (and us) some people might not change the keys afterwards. So instead of giving just you access to the vacuum, other people would have also access to your vacuum. We would like to make the world safer and not more vulnerable. Therefore we are thinking of some solution for that.
### Is Dustcloud breaking the HTTPS connection / any SSL connection?
No, dustcloud requires the symmetric key (extracted from /mnt/default/device.conf) to decrypt the AES connection to the cloud. The same key is used to encrypt the forwarded messages to the cloud.
Note: I personally think that Xiaomis approach of device's unique AES key solves a lot of cloud problems: authentication, integrity (over hmac) and confidentiality.
### Is there a risk that Xiaomi do a force update and disable the root?
Technically there is, but i do not believe so. In any case you can disable updates (yours and Xiaomi's) by renaming the ccrypt command. See [disable-UPDATES.md](https://github.com/dgiese/dustcloud/blob/master/disable-UPDATES.md) for additional information. 
### Will you publish rooting methods for other devices (like other vacuums, smarthome-devices, etc)?
There are plans for that. But keep in mind that the devices were financed from my private budget, therefore the focus will be on devices that i will use myself after the hacking. Do not expect a smart fridge (i have a stupid one already) or a smart car (too expensive). However if you have broken devices (like a used Air purifier or something) or spare devices you want to get rid of, you can contact me. I might be interested in some PCBs ;)

# Contact
* Dennis Giese <dgi[at]posteo.de>
* Daniel Wegemer <daniel[at]wegemer.com>

# Acknowledgements:
### Prof. Matthias Hollick at Secure Mobile Networking Lab (SEEMOO)
<a href="https://www.seemoo.tu-darmstadt.de">![SEEMOO logo](https://github.com/dgiese/dustcloud/raw/master/gfx/seemoo.png)</a>
### Prof. Guevara Noubir (CCIS, Northeastern University)
<a href="http://www.ccs.neu.edu/home/noubir/Home.html">![CCIS logo](https://github.com/dgiese/dustcloud/raw/master/gfx/CCISLogo_S_gR.png)</a>

# Media coverage:
* https://www.golem.de/news/xiaomi-mit-einem-stueck-alufolie-autonome-staubsauger-rooten-1712-131883.html
* http://www.zeit.de/digital/datenschutz/2017-12/34c3-hack-staubsauger-iot
* https://hackaday.com/2017/12/27/34c3-the-first-day-is-a-doozy/
* https://m.heise.de/newsticker/meldung/34C3-Vernetzter-Staubsauger-Roboter-aus-China-gehackt-3928360.html
* https://www.notebookcheck.com/Security-Staubsauger-sammelt-neben-Staub-auch-Daten-ueber-die-Wohnung.275668.0.html
* https://derstandard.at/2000071134392/Sicherheitsforscher-hacken-Staubsaugerroboter-und-finden-Bedenkliches (at some points very inaccurate)
