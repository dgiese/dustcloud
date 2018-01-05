#!/usr/bin/env python3

# Author: Dennis Giese [dustcloud@1338-1.org]
# Copyright 2017 by Dennis Giese

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#TODO: change myCloudserverIP to your CloudserverIP (the IP where this script is running)

import socketserver, subprocess, sys, socket
import threading
from pprint import pprint
import random
import json
import binascii
import hashlib
import json
import datetime
import struct
import time
import pymysql
import select
import ast
from miio.protocol import Message

class CloudClient():

	def __init__(self):
		self.db = pymysql.connect("localhost","dustcloud","","dustcloud")
		self.cursor = self.db.cursor()
	
	def __del__(self):
		print("Class destroyed")
		self.db.close()
	
	def do_log(self, did, data, direction):
		data= "%s" % data
		try:
			self.cursor.execute("Insert into statuslog(did, data, direction) VALUES(%s, %s, %s)",(did,data,direction))
			self.db.commit()
		except Exception as e:
			# Rollback in case there is any error
			print(self.cursor._last_executed)
			print("!!! (eee) SQL rollback : %s" % str(e))
			self.db.rollback()
			
	def do_log_raw(self, did, data, direction):
		data= "%s" % data
		try:
			self.cursor.execute("Insert into raw(did, raw, direction) VALUES(%s, %s, %s)",(did,data,direction))
			self.db.commit()
		except Exception as e:
			# Rollback in case there is any error
			print("!!! (eee) SQL rollback : %s" % str(e))
			self.db.rollback()
		return

	def set_last_contact(self, ddid, client_address, connmode):
		try:
			self.cursor.execute("UPDATE devices SET last_contact = now(), last_contact_from = %s, last_contact_via = %s WHERE did = %s", (client_address, connmode, ddid))
			self.db.commit()
		except Exception as e:
			# Rollback in case there is any error
			print("!!! (eee) SQL rollback : %s" % str(e))
			self.db.rollback()
		
	def confirm_commands(self, ddid, packetid, code):
		try:
			self.cursor.execute("UPDATE cmdqueue SET confirmed = %s WHERE did = %s AND cmdid = %s",(code,ddid,packetid))
			self.db.commit()
		except Exception as e:
			# Rollback in case there is any error
			print("!!! (eee) SQL rollback : %s" % str(e))
			self.db.rollback()
	
	def mark_command_as_processed(self, ddid, packetid):
		try:
			self.cursor.execute("UPDATE cmdqueue SET processed = now() WHERE did = %s AND cmdid = %s",(ddid,packetid))
			self.db.commit()
		except Exception as e:
			# Rollback in case there is any error
			print("!!! (eee) SQL rollback : %s" % str(e))
			self.db.rollback()

		
	def get_commands(self, ddid):
		sql = "SELECT cmdid, method, params FROM cmdqueue WHERE did = '%d' AND expire > now() AND processed < DATE_ADD(NOW(), INTERVAL -1 SECOND) AND confirmed = '0'" % (ddid)
		if self.cursor.execute(sql) > 0:
			# Fetch all the rows in a list of lists.
			results = self.cursor.fetchall()
			for row in results:
				id = row[0]
				method = row[1]
				params = row[2]
				if params == "":
					params = []
				else:
					params = ast.literal_eval(params)
				# Now print fetched result
				print(" ### Command for did = %s, method = %s, params = %s" % (ddid,method,params))
				return {
								"id": id,
								"method":'%s' % method,
								"params": params,
								"from" : '4'
							}
		else:
			#print(" !! no commands")
			return {"id": -1}

	def process_data(self, mysocket,data):
		myCloudserverIP = "10.0.0.1"
		clienthello = bytes.fromhex("21310020ffffffffffffffff0000000000000000000000000000000000000000")
		timestamp = binascii.hexlify(struct.pack('>I', round(time.time()))).decode("utf-8")
		serverhello = bytes.fromhex("21310020ffffffffffffffff" + timestamp + "00000000000000000000000000000000")
		if len(data) == int.from_bytes(data[2:4],byteorder='big'): # Check correct lenght of packet again
			print(" ---------Process Thread-id: %s" % threading.get_ident())
			self.do_log_raw(threading.get_ident(),binascii.hexlify(data), "from_client")
			if data == clienthello:
				print("{} thats a client hello")
				# print("< RAW: %s" % binascii.hexlify(serverhello))
				mysocket.clienthello = data
				mysocket.sendmydata(serverhello)
			elif data[0:12] == clienthello[0:12]:
				print("{} thats a long client hello")
				serverhello = bytes.fromhex("21310020ffffffffffffffff" + timestamp) + data[16:32]
				# print("< RAW: %s" % binascii.hexlify(serverhello))
				mysocket.clienthello = data
				mysocket.sendmydata(serverhello)
			else:
				did = int.from_bytes(data[8:12],byteorder='big')
				fail = 0
				try:
					if self.cursor.execute("SELECT did,name,enckey,forward_to_cloud,full_cloud_forward FROM devices WHERE did = %s",(did)) == 1:
						# Fetch all the rows in a list of lists.
						results = self.cursor.fetchall()
						for row in results:
							ddid = row[0]
							dname = row[1]
							denckey = row[2]
							forward_to_cloud = row[3]
							full_cloud_forward = row[4]
							# Now print fetched result
							print("ddid = %s, dname = %s, denckey = %s, full_cloud_forward = %d, forward_to_cloud = %d" % (ddid,dname,denckey,forward_to_cloud,full_cloud_forward))
					else:
						fail = 1
						print("Error: unable to fetch data for did %s. Device unknown?" % did)
						return 1
				except Exception as e:
					fail = 1
					raise
					print("Error: unable to fetch data for did %s" % did)
					return 1
				if fail == 0:
					enckey = denckey
					enckey = enckey + (16-len(enckey))*"\x00" # extend key if its shorter than 16 bytes
					ctx = {'token': enckey.encode()}
					m = Message.parse(data, ctx)
					if mysocket.ddid != ddid:
						print("(!!!) Warning, did missmatch: %d != %d" % (mysocket.ddid, ddid))
					mysocket.ddid = ddid
					mysocket.ctx = ctx
					mysocket.dname = dname
					mysocket.devtype = m.header.value["devtype"]
					mysocket.devserial = m.header.value["serial"]
					mysocket.forward_to_cloud = forward_to_cloud
					mysocket.full_cloud_forward = full_cloud_forward
					self.set_last_contact(ddid,mysocket.client_address[0],mysocket.connmode)
					print("Headertime %s " %m.header.value["ts"])
					print("Localtime %s " %datetime.datetime.utcnow() )
					
					if m.data["length"] > 0:
						method = m.data.value.get("method", "NONE")
						device_result = m.data.value.get("result", "NONE")
						device_error = m.data.value.get("error", "NONE")
						packetid = m.data.value.get("id", 0)
						print("%s : messageID: %s Method: %s " % (dname,packetid,method))
						print("%s : Value: %s" % (dname,m.data.value))
						if method == "_otc.info":
							params = m.data.value["params"]
							try:
								self.cursor.execute("UPDATE devices SET token = %s, fw = %s, mac = %s, ssid = %s, model = %s, netinfo = %s WHERE did = %s",
							(params["token"],params["fw_ver"],params["mac"],params["ap"]["ssid"],params["model"],params["netif"]["localIp"],did))
								self.db.commit()
							except Exception as e:
								# Rollback in case there is any error
								print("!!! (eee) SQL rollback : %s" % str(e))
								self.db.rollback()

							self.do_log(did, m.data.value, "from_client")
							cmd = {
								"id": packetid,
								"result": {"otc_list":[{"ip":myCloudserverIP,"port":80}],
										   "otc_test":{"list":[{"ip":myCloudserverIP,"port":8053}],
										   "interval":1800, "firsttest":769}}
							}
							if ((mysocket.forward_to_cloud == 1) or (mysocket.full_cloud_forward == 1)):
								self.do_log(did,m.data.value,"to_cloud(blck_resp)")
								mysocket.blocked_from_cloud_list.append(packetid) # block real otc_info response from cloud
								mysocket.send_data_to_cloud(data)
						elif method in mysocket.status_methods:
							self.do_log(did,m.data.value,"from_client")
							cmd = {
								"id": packetid,
								"result": "ok"
							}
							if ((mysocket.forward_to_cloud == 1) or (mysocket.full_cloud_forward == 1)):
								self.do_log(did,m.data.value,"to_cloud(status)")
								mysocket.send_data_to_cloud(data)
								return 0
						elif (method == "NONE" and (device_result != "NONE" or device_error != "NONE")):
							self.do_log(did, m.data.value, "from_client")
							if device_error == "NONE":
								self.confirm_commands(did, packetid, 1)
							else:
								self.confirm_commands(did, packetid, -1)
							cmd = {
								"id": packetid,
								"result": "ok"
							}
							if ((mysocket.full_cloud_forward == 1) and (packetid not in mysocket.blocked_from_client_list)):
								self.do_log(did,m.data.value,"to_cloud(result)")
								mysocket.send_data_to_cloud(data)
							if (packetid in mysocket.blocked_from_client_list):
								mysocket.blocked_from_client_list.remove(packetid)
								
						elif (method == "_sync.batch_gen_room_up_url"):
							self.do_log(did, m.data.value, "from_client")
							# cmd = {
								# "id": packetid,
								# "result": ["https://xxx/index.php?id=1",
								# "https://xxx/index.php?id=2",
								# "https://xxx/index.php?id=3",
								# "https://xxx/index.php?id=4"]
							# }
							if ((mysocket.forward_to_cloud == 1) or (mysocket.full_cloud_forward == 1)):
								self.do_log(did,m.data.value,"to_cloud()")
								# mysocket.blocked_from_cloud_list.append(packetid) # block real response from cloud
								mysocket.send_data_to_cloud(data)
							return 0
								
						else:
							print("%s : unknown method" % dname)
							self.do_log(did, m.data.value, "from_client")
							cmd = {
								"id": packetid,
								"result": "ok"
							}
						self.do_log(did,cmd,"from_dustcloud")
						send_ts = m.header.value["ts"] + datetime.timedelta(seconds=1)
						header = {'length': 0, 'unknown': 0x00000000,
								  'devtype': m.header.value["devtype"], 'serial': m.header.value["serial"],
								  'ts': send_ts}

						msg = {'data': {'value': cmd},
							   'header': {'value': header},
							   'checksum': 0}
						c = Message.build(msg, ctx)
						print("%s : prepare response" % dname)
						print("%s : Value: %s" % (dname,cmd))
						#print("< RAW: %s" % binascii.hexlify(c))
						mysocket.sendmydata(c)
					else:
						print("%s : Ping-Pong" % dname)
						if ((mysocket.forward_to_cloud == 1) or (mysocket.full_cloud_forward == 1)):
							#self.do_log(did,"PING (len=32)","to_cloud(ping)")
							mysocket.send_data_to_cloud(data)
						else:
							print("< RAW: %s" % binascii.hexlify(data))
							mysocket.sendmydata(data) # Ping-Pong
		else:
			print("Wrong packet size %s %s " % (len(data),int.from_bytes(data[2:4],byteorder='big')))
			return 1
		return 0
		
	def process_cloud_data(self, mysocket,data):
		if len(data) == int.from_bytes(data[2:4],byteorder='big'): # Check correct lenght of packet again
			print(threading.get_ident())
			did = int.from_bytes(data[8:12],byteorder='big')
			self.do_log_raw(did,binascii.hexlify(data), "from_cloud")
			
			if did == mysocket.ddid:
				m = Message.parse(data, mysocket.ctx)
				print("Headertime %s " %m.header.value["ts"])
				print("Localtime %s " %datetime.datetime.utcnow() )
				
				if m.data["length"] > 0:
					method = m.data.value.get("method", "NONE")
					device_result = m.data.value.get("result", "NONE")
					device_error = m.data.value.get("error", "NONE")
					packetid = m.data.value.get("id", 0)
					print("Cloud->%s : messageID: %s Method: %s " % (mysocket.dname,packetid,method))
					print("Cloud->%s : Value: %s" % (mysocket.dname,m.data.value))
					self.do_log(did, m.data.value, "from_cloud")
					if (mysocket.full_cloud_forward == 1 and (method not in mysocket.blocked_methods_from_cloud_list) and (packetid not in mysocket.blocked_from_cloud_list)):
							mysocket.sendmydata(data) # forward data to client
					if (packetid in mysocket.blocked_from_client_list):
							mysocket.blocked_from_cloud_list.remove(packetid)
				else:
					print("Cloud->%s : Ping-Pong" % mysocket.dname)
					if ((mysocket.forward_to_cloud == 1) or (mysocket.full_cloud_forward == 1)):
						#self.do_log(did,"PING-PONG (len=32)","from_cloud(ping)")
						mysocket.sendmydata(data) # forward data to client	
		else:
			print("Wrong packet size %s %s " % (len(data),int.from_bytes(data[2:4],byteorder='big')))
			return 1
		return 0

class SingleTCPHandler(socketserver.BaseRequestHandler):
	ddid = 0
	ctx = ""
	devtype = ""
	devserial = ""
	dname = ""
	sended = 0
	commandcounter = 0
	lastmessageid = 0
	connmode = "tcp"
	cloudstate = ""
	#socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	server_address = ('ot.io.mi.com', 80)
	blocked_from_client_list = []
	blocked_from_cloud_list = []
	blocked_methods_from_cloud_list = ['miIO.ota','miIO.config_router','enable_log_upload']
	status_methods = ['event.status','props','event.keepalive','event.remove','event.motion','event.heartbeat','event.click','_sync.upLocalSceneRuningLog','_async.store','_otc.log','event.dry','event.no_motion','event.comfortable']
	
	"One instance per connection.  Override handle(self) to customize action."
	
	def connect_to_cloud(self):
		print('!!!!!! connecting to {} port {}'.format(*self.server_address))
		self.sock.connect(self.server_address)
		self.send_data_to_cloud(self.clienthello)
		serverresp = self.sock.recv(1024)
		print("###### received from Cloud (len: %d) :%s " % (len(serverresp), binascii.hexlify(serverresp)))
		self.Cloudi.do_log_raw(self.ddid,binascii.hexlify(serverresp), "from_cloud")
	
	def send_data_to_cloud(self,data):
		if self.cloudstate == "offline":
			self.cloudstate = "online"
			self.connect_to_cloud()
		self.Cloudi.do_log_raw(self.ddid,binascii.hexlify(data), "to_cloud")
		# print("C< RAW: %s" % binascii.hexlify(data))
		self.sock.sendall(data)
		return
	
	def sendmydata(self,data):
		self.Cloudi.do_log_raw(self.ddid,binascii.hexlify(data), "from_dustcloud")
		if (self.request.fileno() < 0):
				return
		self.request.send(data)
		
	def handle(self):
		# self.request is the client connection
		print(" --------------- Thread-id: %s" % threading.get_ident())
		self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		if self.cloudstate != "online":
			self.cloudstate = "offline"
		self.Cloudi = CloudClient()
		while True :
			if (self.request.fileno() < 0):
				break
			if self.cloudstate == "online":
				if (self.sock.fileno() < 0):
					print("Cloud connection disconnected")
					self.sock.close()
					self.cloudstate = "offline"
				break
				r,w,x = select.select([self.request, self.sock],[],[],1)
			else:
				r,w,x = select.select([self.request],[],[],1)
			for s in r:
					if s == self.request:
						self.on_read()
					if s == self.sock:
						self.on_read_cloud()
			if self.ddid != 0:
				if self.sended == 0:
					queue_return = self.Cloudi.get_commands(self.ddid)
					#print("Queue:")
					#print(queue_return["id"])
					#print(self.commandcounter)
					#if queue_return["id"] >= self.commandcounter:
					if queue_return["id"] >= 0:
						self.commandcounter = queue_return["id"]
						self.Cloudi.mark_command_as_processed(self.ddid,queue_return["id"])
						cmd = queue_return
						cmd["id"] = self.commandcounter
						self.blocked_from_client_list.append(cmd["id"])  # add to blocklist to not forward results from my cmds to the cloud
						send_ts = datetime.datetime.utcnow()  + datetime.timedelta(seconds=1)
						header = {'length': 0, 'unknown': 0x00000000,
							  'devtype': self.devtype, 'serial': self.devserial,
							  'ts': send_ts}
						msg = {'data': {'value': cmd},
							   'header': {'value': header},
							   'checksum': 0}
						self.Cloudi.do_log(self.ddid,cmd, "to_client(cmd)")
						print("Sendtime %s " % send_ts )
						print("Localtime %s " % datetime.datetime.utcnow() )
						c = Message.build(msg, self.ctx)
						print("%s : prepare response (command)" % self.dname)
						print("%s : Value: %s" % (self.dname,msg))
						# print("< RAW: %s" % binascii.hexlify(c))
						self.sendmydata(c)
		print("Close Request")
		self.sock.close()
		self.request.close()
		
	def on_read_cloud(self):
		data = self.sock.recv(32)  # wait to get the first 32 bytes (header+md5)
		print("{} via tcp wrote:".format(self.client_address[0]))
		# print("C> RAW: %s" % binascii.hexlify(data))
		if len(data) < 32: # should never receive anything smaller than 32 byte
			print("len < 32")
			self.sock.close()
			return
		else:
			if data[0:2] == bytes.fromhex("2131"):  # Check for magic bytes
				print("magic ok")
				packetlenght = int.from_bytes(data[2:4],byteorder='big'); # get packet lenght from header
				# print("packetlength %s, got already %s " % (packetlenght,len(data)))
				if len(data) != packetlenght: # packet longer than 32 byte
					data += self.sock.recv((packetlenght-32)) # get the rest of the packet
					# print("packetlength %s, got now %s " % (packetlenght,len(data)))
					# print("= RAW: %s" % binascii.hexlify(data))
					self.Cloudi.do_log_raw(self.ddid,binascii.hexlify(data), "from_cloud")
				process_result = self.Cloudi.process_cloud_data(self,data)
				#if process_result == 1:
					#self.request.close()
					#return
		
	def on_read(self):
		data = self.request.recv(32)  # wait to get the first 32 bytes (header+md5)
		print("{} via tcp wrote:".format(self.client_address[0]))
		#print("> RAW: %s" % binascii.hexlify(data))
		if len(data) < 32: # should never receive anything smaller than 32 byte
			print("len < 32")
			self.request.close()
			return
		else:
			if data[0:2] == bytes.fromhex("2131"):  # Check for magic bytes
				print("magic ok")
				packetlenght = int.from_bytes(data[2:4],byteorder='big'); # get packet lenght from header
				# print("packetlength %s, got already %s " % (packetlenght,len(data)))
				if len(data) != packetlenght: # packet longer than 32 byte
					data += self.request.recv((packetlenght-32)) # get the rest of the packet
					# print("packetlength %s, got now %s " % (packetlenght,len(data)))
					# print("= RAW: %s" % binascii.hexlify(data))
				process_result = self.Cloudi.process_data(self,data)
				if process_result == 1:
					self.request.close()
					return
			else:
				self.httpmode=1
				print("Magic bytes were missing, echo http redirection")
				self.http(data)
				http = "HTTP/1.1 302 Found\n"
				http = http + "Location: https://xxx/\n"
				http = http + "Content-Length: 212\n"
				http = http + "Content-Type: text/html; charset=iso-8859-1\n"
				http = http + "\n"
				http = http + "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
				http = http + "<html><head>\n"
				http = http + "<title>302 Found</title>\n"
				http = http + "</head><body>\n"
				http = http + "<h1>Found</h1>\n"
				http = http + "<p>The document has moved <a href=\"https://xxx/\">here</a>.</p>\n"
				http = http + "</body></html>"
				# self.request.send(http.encode('utf-8'))
				self.request.close()
				return
				
	def http(self,firstdata):
		server_address = ('localhost', 5080)
		self.sock.connect(server_address)
		while True :
			if (self.request.fileno() < 0):
				break
			r,w,x = select.select([self.request, self.sock],[],[])
			for s in r:
				data = s.recv(4096)
				if len(data) == 0:
					self.request.close()
					break
				if s == self.request:
					self.sock.sendall(firstdata+data)
					firstdata = ""
				if s == self.sock:
					self.request.send(data)
			
		
class MyUDPHandler(socketserver.BaseRequestHandler):
	"""
	This class works similar to the TCP handler class, except that
	self.request consists of a pair of data and client socket, and since
	there is no connection the client address must be given explicitly
	when sending data back via sendto().
	"""
	clienthello = ""
	ddid = 0
	ctx = ""
	devtype = ""
	devserial = ""
	dname = ""
	sended = 0
	commandcounter = 0
	lastmessageid = 0
	connmode= "udp"
	
	def sendmydata(self,data):
		self.request.sendto(data, self.client_address)

	def handle(self):
		data = self.request[0].strip()
		socket = self.request[1]
		print("{} via udp wrote:".format(self.client_address[0]))
		# print("> RAW: %s" % binascii.hexlify(data))
		if len(data) < 32:
			print("len < 32")
			return
		else:
			if data[0:2] == bytes.fromhex("2131"):  # Check for magic bytes
				print("magic ok")
				process_data(socket,data)


class TCPSimpleServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
	# Ctrl-C will cleanly kill all spawned threads
	daemon_threads = True
	# much faster rebinding
	allow_reuse_address = True

	def __init__(self, server_address, RequestHandlerClass):
		socketserver.TCPServer.__init__(self, server_address, RequestHandlerClass)

class UDPSimpleServer(socketserver.ThreadingMixIn, socketserver.UDPServer):
	# Ctrl-C will cleanly kill all spawned threads
	daemon_threads = True
	# much faster rebinding
	allow_reuse_address = True

	def __init__(self, server_address, RequestHandlerClass):
		socketserver.UDPServer.__init__(self, server_address, RequestHandlerClass)

		
if __name__ == "__main__":
	tcpserver = TCPSimpleServer(("0.0.0.0", 80), SingleTCPHandler)
	udpserver = UDPSimpleServer(("0.0.0.0", 8054), MyUDPHandler) ## disable UDP interface
	# terminate with Ctrl-C
	try:
		tcpserver.serve_forever()
		udpserver.serve_forever()
	except KeyboardInterrupt:
		sys.exit(0)
