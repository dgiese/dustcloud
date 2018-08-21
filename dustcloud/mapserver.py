#!/usr/bin/env python3

# Author: Dennis Giese [dustcloud@1338-1.org]
# Copyright 2017 by Dennis Giese

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import os
import re
import socketserver
import json
import configparser
from bottle import route, run

configParser = configparser.RawConfigParser()
configFilePath = os.path.dirname(os.path.realpath(__file__)) + '/config.ini'
configParser.read(configFilePath)
listenaddr = configParser.get('cloudserver', 'mapaddr')
listenport = int(configParser.get('cloudserver', 'mapport'))

slamdata = {}
class MyTCPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request.recv(31).strip()
        if data[0:14] == b"ROCKROBO_MAP__":
            print("===== {} =====".format(self.client_address[0]))
            payload = self.request.recv(int(data[15:31]) + 1)
            did = re.search(b'did=(.+?)\\n', payload).group(1).decode()
            slam = re.search(b'did=.+?\\n(.+?)$', payload).group(1).decode().split(' ')
            print(did)
            print(slam)
            if slam[1] == "estimate":
                if not did in slamdata:
                    slamdata[did] = {}
                slamdata[did][round(float(slam[0]))] = {'t': float(slam[0]), 'x': float(slam[2]), 'y': float(slam[3]), 'z': float(slam[4])}
            elif slam[1] == "reset":
                if did in slamdata:
                    slamdata[did] = []
        elif re.search(b'GET /([^ ]+) HTTP/1.?', data[0:22]):
            print("===== {} =====".format(self.client_address[0]))
            print(data[0:22].decode())
            did = re.search(b'GET /([^ ]+) HTTP/1.?', data[0:22]).group(1)
            print("HTTP Request for " + did.decode())
            if did.decode() in slamdata:
                print("OK")
                http = "HTTP/1.0 200 OK\n"
                http = http + "Content-Type: application/json; charset=UTF-8\n\n"
                http = http + json.dumps(slamdata[did.decode()])
            else:
                print("Not Found")
                http = "HTTP/1.0 404 Not Found\n"
                http = http + "Content-Type: application/json; charset=UTF-8\n\n"
                http = http + "{}"
            self.request.send(http.encode('utf-8'))
        elif data[0:13] == b"GET / HTTP/1.":
            print("===== {} =====".format(self.client_address[0]))
            print(data[0:14].decode())
            print("Bad Request")
            http = "HTTP/1.0 400 Bad Request\n"
            http = http + "Content-Type: text/html; charset=UTF-8\n"
            http = http + "\n"
            http = http + "<h1>400 Bad Request</h1>"
            self.request.send(http.encode('utf-8'))


class TCPSimpleServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    # Ctrl-C will cleanly kill all spawned threads
    daemon_threads = True
    # much faster rebinding
    allow_reuse_address = True

    def __init__(self, server_address, request_handler_class):
        socketserver.TCPServer.__init__(self, server_address, request_handler_class)

if __name__ == "__main__":
	server = TCPSimpleServer((listenaddr, listenport), MyTCPHandler)
	server.serve_forever()

