Firmwareupdates and soundpackages require the command ccrypt to work properly. Any update must be decrypted by that command.
By renaming it, you technically disable your vacuum's ability to update firmware/install soundpackages.

> mv /usr/bin/ccrypt /usr/bin/ccrypt_
> touch /usr/bin/ccrypt
> chmod +x /usr/bin/ccrypt
