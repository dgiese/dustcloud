#!/usr/bin/env python3

# Author: Thomas Tsiakalakis [mail@tsia.de]
# Copyright 2018 by Thomas Tsiakalakis

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
lastreset = {}


class MyTCPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request.recv(31).strip()
        httplength = data.find(b'\n')
        print(data[0:httplength]);
        if data[0:14] == b"ROCKROBO_MAP__":
            print("===== {} =====".format(self.client_address[0]))
            payload = self.request.recv(int(data[15:31]) + 1)
            did = re.search(b'did=(.+?)\\n', payload).group(1).decode()
            slam = re.search(b'did=.+?\\n(.+?)$', payload).group(1).decode().split(' ')
            print(did)
            print(slam)
            if slam[1] == "estimate":
                if not did in slamdata:
                    slamdata[did] = []

                if did not in lastreset:
                    lastreset[did] = float(0)

                slamdata[did].append({'t': float(slam[0]),
                                      'y': float(slam[2]),
                                      'x': float(slam[3]),
                                      'z': float(slam[4])})
            elif slam[1] == "resume":
                if did in slamdata:
                    slamdata[did] = []
                lastreset[did] = float(slam[0])
        elif re.search(b'GET /([^ /]+)(/all)? HTTP/1\\.[0-9]', data[0:httplength]):
            print("===== {} =====".format(self.client_address[0]))
            print(data[0:httplength].decode())
            matches = re.search(b'GET /([^ /]+)(/all)? HTTP/1\\.[0-9]', data[0:httplength])
            did = matches.group(1)
            print("HTTP Request for " + did.decode())
            printall = matches.group(2)
            if did.decode() in slamdata:
                print("OK")
                http = "HTTP/1.0 200 OK\n"
                http += "Content-Type: application/json; charset=UTF-8\n\n"
                if printall == b"/all":
                    http += json.dumps({'reset': lastreset[did.decode()], 'data': slamdata[did.decode()]})
                else:
                    http += json.dumps({'reset': lastreset[did.decode()], 'data': slamdata[did.decode()][-3:]})
            else:
                print("Not Found")
                http = "HTTP/1.0 404 Not Found\n"
                http += "Content-Type: application/json; charset=UTF-8\n\n"
                http += "{}"
            self.request.send(http.encode('utf-8'))
        elif data[0:13] == b"GET / HTTP/1.":
            print("===== {} =====".format(self.client_address[0]))
            print(data[0:14].decode())
            print("Bad Request")
            http = "HTTP/1.0 400 Bad Request\n"
            http += "Content-Type: text/html; charset=UTF-8\n"
            http += "\n"
            http += "<h1>400 Bad Request</h1>"
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
