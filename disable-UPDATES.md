Firmwareupdates and soundpackages require the command ccrypt to work properly. Any update must be decrypted by that command.
By renaming it, you technically disable your vacuum's ability to update firmware/install soundpackages.

> mv /usr/bin/ccrypt /usr/bin/ccrypt_

> touch /usr/bin/ccrypt

> chmod +x /usr/bin/ccrypt

### Reverse (to install updates and soundpackages again) 
Check that /usr/bin/ccrypt_ exists (you do not want to delete your actual copy of ccrypt)

> rm /usr/bin/ccrypt

> mv /usr/bin/ccrypt_ /usr/bin/ccrypt
