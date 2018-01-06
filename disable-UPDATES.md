Firmwareupdates and soundpackages require the command ccrypt to work properly. Any update must be decrypted by that command.
By removing `ccrypt`, you technically disable your vacuum's ability to update firmware/install soundpackages.

> apt-get remove ccrypt

### Reverse (to install updates and soundpackages again) 

> apt-get install ccrypt
