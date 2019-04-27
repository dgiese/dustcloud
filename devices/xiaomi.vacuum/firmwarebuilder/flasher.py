#!/usr/bin/env python3
# This file is part of the "Dustcloud" xiaomi vacuum hacking project
# Copyright 2017 by Dennis Giese and contributors

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program. If not, see <http://www.gnu.org/licenses/>.
#

import binascii
import socket
import hashlib
import json
import sys
import argparse
import http.server
import socketserver
import os
import threading
from time import sleep
from typing import List
import miio


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


def printProgressBar (iteration, total, prefix = '', suffix = '', decimals = 1, length = 100, fill = '█'):
    '''
    https://stackoverflow.com/questions/3173320/text-progress-bar-in-the-console/34325723#34325723
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
    '''
    percent = ('{0:.' + str(decimals) + 'f}').format(100 * (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print('\r%s |%s| %s%% %s' % (prefix, bar, percent, suffix), end = '\r')
    # Clear Line on Complete
    if iteration == total:
        print('\r' + ' ' * (len(prefix) + length + len(suffix) + 11))


def md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def findIP():
    return ((([ip for ip in socket.gethostbyname_ex(socket.gethostname())[2] if not ip.startswith('127.')] or [[(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]]) + ['no IP found'])[0])


def discover_devices():
    timeout = 5
    # type: List[str]
    seen_addrs = []
    addr = '<broadcast>'
    # magic, length 32
    helobytes = bytes.fromhex('21310020ffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.settimeout(timeout)
    s.sendto(helobytes, (addr, 54321))
    while True:
        try:
            data, addr = s.recvfrom(1024)
            if addr[0] not in seen_addrs:
                seen_addrs.append(addr[0])
        except socket.timeout:
            break  # ignore timeouts on discover
        except Exception as ex:
            print('Error while reading discover results:', ex)
            break
    return seen_addrs


def select_item(welcome_text, items):
    print(welcome_text)
    for i, item in enumerate(items):
        print('{}. {}'.format(i+1, item))
    try:
        selected = input('Please select option by typing number (1-{}): '.format(len(items)))
        result = items[int(selected)-1]
        return result
    except KeyboardInterrupt:
        print('User requested to exit')
        exit()
    except ValueError:
        print('Error! Please enter only one number')
        exit()
    except IndexError:
        print('Error! Please enter one number between 1-{}'.format(len(items)))
        exit()


def main():
    parser = argparse.ArgumentParser(description='Flasher for Xiaomi Vacuum.\nFor specific options check \'{} --help\''.format(sys.argv[0]))
    parser.add_argument('-a', '--address', dest='address', type=str, help='IP address of vacuum cleaner')
    parser.add_argument('-t', '--token', dest='token', type=str, help='Known token of vacuum')
    parser.add_argument('-f', '--firmware', dest='firmware', type=str, help='Path to firmware file')

    args, external = parser.parse_known_args()

    print('Flasher for Xiaomi Vacuum')

    ip_address = args.address
    known_token = args.token
    firmware = os.path.abspath(args.firmware)



    if not args.firmware and not os.path.isfile(firmware):
        print('You should specify firmware file name to install')
        exit()

    if not ip_address:
        print('Address is not set. Trying to discover.')
        seen_addrs = discover_devices()

        if len(seen_addrs) == 0:
            print('No devices discovered.')
            exit()
        elif len(seen_addrs) == 1:
            ip_address = seen_addrs[0]
        else:
            ip_address = select_item('Choose device for connection:', seen_addrs)

    print('Connecting to device {}...'.format(ip_address))
    vacuum = miio.Vacuum(ip=ip_address, token=known_token)
    if not known_token:
        print('Sending handshake to get token')
        m = vacuum.do_discover()
        vacuum.token = m.checksum
    else:
        if len(known_token) == 16:
            known_token = str(binascii.hexlify(bytes(known_token, encoding="utf8")))
    try:
        s = vacuum.status()
        if s.state == 'Updating':
            print('Device already updating.')
            exit()
        elif s.state != 'Charging':
            print('Put device to charging station for updating firmware.')
            exit()
    except Exception as ex:
        print('error while checking device:', ex)
        exit()

    local_ip = findIP()
    os.chdir(os.path.dirname(firmware))

    request_handler = http.server.SimpleHTTPRequestHandler
    httpd = ThreadedHTTPServer(('', 0), request_handler)
    http_port = httpd.server_address[1]

    print('Starting local http server...')
    thread = threading.Thread(target=httpd.handle_request, daemon=True)
    thread.start()
    print('Serving http server at {}:{}'.format(local_ip, http_port))

    ota_params = {
        'mode': 'normal',
        'install': '1',
        'app_url': 'http://{ip}:{port}/{fw}'.format(ip=local_ip, port=http_port, fw=os.path.basename(firmware)),
        'file_md5': md5(firmware),
        'proc': 'dnld install'
    }
    print('Sending ota command with parameters:', json.dumps(ota_params))
    r = vacuum.send('miIO.ota', ota_params)
    if r[0] == 'ok':
        print('Ota started!')
    else:
        print('Got error response for ota command:', r)
        exit()

    ota_progress = 0
    while ota_progress < 100:
        ota_state = vacuum.send('miIO.get_ota_state')[0]
        ota_progress = vacuum.send('miIO.get_ota_progress')[0]
        printProgressBar(ota_progress, 100, prefix = 'Progress:', length = 50)
        sleep(2)
    print('Firmware downloaded successfully.')

    httpd.server_close()

    print('Exiting.')
    exit()


if __name__ == '__main__':
    main()
