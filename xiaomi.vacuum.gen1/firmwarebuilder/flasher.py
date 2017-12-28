#!/usr/bin/env python

import re
import os
import subprocess
import time
import socket
import hashlib
import json

def md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


from prompt_toolkit import prompt
print('Flasher for Xiaomi Vacuum')
print('trying to find the vacuum')




process = subprocess.Popen(['mirobo','discover','--handshake','true'], stdout=subprocess.PIPE,stderr=subprocess.PIPE)
time.sleep(1);
process.terminate();
output = process.stderr.read()


#output = "IP 192.168.8.1: default - token: b'FFFFFFFFFFFFFFFFFFFFFF'"
try:
    m = re.search("b'(.+?)'", output)
    token = m.group(1)
    m = re.search("IP (.+?)\:", output)
    ip = m.group(1)
except:
    print('Vacuum not found...Check connection')
    exit()




cmd = "mirobo --ip="+ip+" --token=" + token + " status"
print("Execute following for status:" + cmd)
#ret = os.system(cmd)
#if ret != "status":
#    print("Something gone wrong while getting status....")
#    exit()


localIP = socket.gethostbyname(socket.getfqdn())
updatefile = "v11_003077.pkg"
datajson = {
"mode":"normal",
"install":"1",
"app_url":"http://"+localIP+"/"+updatefile,
"file_md5":md5(updatefile),
"proc":"dnld install"
}




cmd = "mirobo --ip="+ip+" --token=" + token
cmd = cmd +  " raw_command miIO.ota "
cmd = cmd + "'" + json.dumps(datajson) + "'"
print("Use following Command to update:" + cmd)


