/*
 Copyright 2018 by Dustcloud Project (Author: S.)

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
*/

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <linux/udp.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <ctype.h>
#include <time.h>
#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#include "common_socket.h"
#include "hexdump.h"
#include "md5.h"
#include "aes.h"
#include "pkcs7_padding.h"
#include "cJSON.h"

#define DC_VERSION "0.1.0-20180808"

#define PORT 8053 /* Default port */
#define DEVICE_CONF "/mnt/default/device.conf" /* Default file for key */
#define PACKET_BUF_SIZE 8192 /* Maximum size of packet */

#define LOGLEVEL_QUIET 0
#define LOGLEVEL_VERBOSE 1
#define LOGLEVEL_DEBUG 2
#define LOGLEVEL_PACKETDUMP 444

#define say(level,fmt, ...) \
            do { if (verbose >= level) fprintf(stdout, fmt, ##__VA_ARGS__); } while (0)

#ifndef __USE_GNU
/* IPv6 packet information - in cmsg_data[] */
struct in6_pktinfo
{
	struct in6_addr ipi6_addr;	/* src/dst IPv6 address */
	unsigned int ipi6_ifindex;	/* send/recv interface index */
};
#endif

// Dummy for decryption test
// Can be filled with a real packet, given decryption key to see its contents
uint8_t test_packet[] = { "Dummy packet" };

uint8_t hello_packet[32] = {
	// Magic   Length     Unknown              DID                  Epoch big-endian
	0x21,0x31, 0x00,0x20, 0xff,0xff,0xff,0xff, 0xff,0xff,0xff,0xff, 0x00,0x00,0x00,0x00,
	// Checksum md5(Header+Key+Data)
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	// Encrypted data
	// key = md5(key_str)
	// iv = md5(key+key_str)
	// cipher = AES(key,AES.MODE_CBC,iv,padded plaintext)
};

uint8_t key_str[17]="\0";
int verbose = 0;

int pktinfo_get(struct msghdr *my_hdr, struct in_pktinfo *pktinfo, struct in6_pktinfo *pktinfo6)
{
	int res = -1;

	if (my_hdr->msg_controllen > 0) {
		struct cmsghdr *get_cmsg;
		for (get_cmsg = CMSG_FIRSTHDR(my_hdr); get_cmsg;
		     get_cmsg = CMSG_NXTHDR(my_hdr, get_cmsg)) {
			if (get_cmsg->cmsg_level == IPPROTO_IP &&
			    get_cmsg->cmsg_type  == IP_PKTINFO) {
				struct in_pktinfo *get_pktinfo = (struct in_pktinfo *)CMSG_DATA(get_cmsg);
				memcpy(pktinfo, get_pktinfo, sizeof(*pktinfo));
				res = AF_INET;
			} else if (get_cmsg->cmsg_level == IPPROTO_IPV6 &&
				   get_cmsg->cmsg_type  == IPV6_PKTINFO
				) {
				struct in6_pktinfo *get_pktinfo = (struct in6_pktinfo *)CMSG_DATA(get_cmsg);
				memcpy(pktinfo6, get_pktinfo, sizeof(*pktinfo6));
				res = AF_INET6;
			} else {
				say(LOGLEVEL_QUIET,"Unknown ancillary data, len=%zu, level=%d, type=%d\n",
					get_cmsg->cmsg_len, get_cmsg->cmsg_level, get_cmsg->cmsg_type);
			}
		}
	}
	return res;
}

int pktinfo_to(struct msghdr *my_hdr, char *to_addr, int to_addr_size)
{
	struct in_pktinfo pktinfo;
	struct in6_pktinfo pktinfo6;
	char from_addr[INET6_ADDRSTRLEN];
	//uint16_t rem_port;

	memset(to_addr, 0, to_addr_size);
	int addr_family = pktinfo_get(my_hdr, &pktinfo, &pktinfo6);

	/* msghdr->msg_name -- contains remote addr pointer */
	if (addr_family == AF_INET) {
		struct sockaddr_in *rem_addr = (struct sockaddr_in *) my_hdr->msg_name;
		if (!inet_ntop(addr_family, (void*)&rem_addr->sin_addr, from_addr, sizeof(from_addr)))
			perror("inet_ntop");
		if (!inet_ntop(addr_family, (void*)&pktinfo.ipi_spec_dst, to_addr, to_addr_size))
			perror("inet_ntop");
		//rem_port = htons(rem_addr->sin_port);
	} else if (addr_family == AF_INET6) {
		struct sockaddr_in6 *rem_addr = (struct sockaddr_in6 *) my_hdr->msg_name;
		//rem_port = htons(rem_addr->sin6_port);
		if (!inet_ntop(addr_family, (void*)&rem_addr->sin6_addr, from_addr, sizeof(from_addr)))
			perror("inet_ntop");
		if (!inet_ntop(addr_family, (void*)&pktinfo6.ipi6_addr, to_addr, to_addr_size))
			perror("inet_ntop");
	} else {
		say(LOGLEVEL_QUIET,"No destination IP data found (ancillary data)\n");
	}
	return strlen(to_addr);
}

int parse_packet(int len, uint8_t *packet, uint8_t *answer, const uint8_t *aes_key, const uint8_t *aes_iv, char *to_addr, uint16_t to_port)
{
	uint8_t aes_iv_temp[16];
	uint8_t md5_sum[16];
	md5_state_t md5_state;
	time_t ct;
	uint8_t ct_arr[4];
	uint64_t id;
	char method[64];
	char ct_str[32];
	int reply_len;

	// Get current time
	ct = time(NULL);
	ct_arr[3] = ct & 0xFF;
	ct_arr[2] = (ct>>8) & 0xFF;
	ct_arr[1] = (ct>>16) & 0xFF;
	ct_arr[0] = (ct>>24) & 0xFF;
	strftime (ct_str, sizeof(ct_str), "%Y-%m-%d %H:%M:%S", localtime (&ct));
	say(LOGLEVEL_VERBOSE,"[ %s ] ", ct_str);

	// Check for hello or keep-alive packet
	if (len == 32) {
		if (memcmp(&hello_packet[0],&packet[0],sizeof(hello_packet)) == 0) {
			memcpy(answer,packet,16);
			memcpy(&answer[12],ct_arr,4);
			say(LOGLEVEL_VERBOSE,"Received initial ping\n");
			if (verbose >= LOGLEVEL_DEBUG) {
				hexdump(answer,len);
			}
			return len;
		} else {
			memcpy(answer,packet,32);
			say(LOGLEVEL_VERBOSE,"Received keep-alive packet\n");
			if (verbose >= LOGLEVEL_DEBUG) {
				hexdump(answer,len);
			}
			return len;
		}
	}

	// Check packet size
	// 16 header + 16 md5 + 16 padding
	if (len < 48) {
		say(LOGLEVEL_QUIET,"Packet too small, only %d bytes\n", len);
		if (verbose >= LOGLEVEL_DEBUG) {
			hexdump(packet,len);
			printf("\n");
		}
		return 0;
	}

	// Check MD5
	md5_init(&md5_state);
	md5_append(&md5_state, &packet[0], 16);
	md5_append(&md5_state, key_str, strlen((char *)key_str));
	md5_append(&md5_state, &packet[32], len-32);
	md5_finish(&md5_state, md5_sum);
	if (memcmp(&packet[16],md5_sum,16)!=0) {
		say(LOGLEVEL_QUIET,"Packet MD5 checksum incorrect, wrong key?\n");
		return 0;
	}

	// Decrypt data section
	memcpy(aes_iv_temp,aes_iv,sizeof(aes_iv_temp));
	if (AES128_CBC_decrypt_inplace(&packet[32], len-32, aes_key, aes_iv_temp )) {
		say(LOGLEVEL_QUIET,"PKCS7 padding incorrect\n");
		return 0;
	} else {
		if (verbose >= LOGLEVEL_DEBUG) {
			printf("\n");
			hexdump(packet,len);
		}
	}

	// Analyze JSON
	cJSON *json = cJSON_Parse((const char *)&packet[32]);
    if (!json) {
		say(LOGLEVEL_QUIET,"Error before: [%s]\n", cJSON_GetErrorPtr());
		return 0;
	} else {
		int is_err = 0;
		char *json_out = cJSON_Print(json);
		say(LOGLEVEL_VERBOSE,"Received JSON payload\n%s\n", json_out);
    	free(json_out);
		cJSON *json_id = cJSON_GetObjectItemCaseSensitive(json, "id");
		cJSON *json_method = cJSON_GetObjectItemCaseSensitive(json, "method");
		if (cJSON_IsString(json_method) && (json_method->valuestring != NULL)) {
			strncpy(method,json_method->valuestring,sizeof(method)-1);
		} else {
			say(LOGLEVEL_QUIET,"Missing method in JSON\n");
			is_err = 1;
		}
		if (cJSON_IsNumber(json_id)) {
			if (json_id->valuedouble >= 0 && json_id->valuedouble <= UINT64_MAX ) {
				id = json_id->valuedouble;
			} else {
				say(LOGLEVEL_QUIET,"ID value out of range\n");
				is_err = 1;
			}
		} else {
			say(LOGLEVEL_QUIET,"ID value not a number\n");
			is_err = 1;
		}
		cJSON_Delete(json);
		if (is_err) return 0;
    }

	// Method handler
	if (!strcasecmp(method,"_otc.info")) {
		reply_len = 1 +	snprintf((char *)&answer[32],
			PACKET_BUF_SIZE-16-16-16-1, /* buffer - header - md5 - padding - zero */
			"{\"id\":%"PRIu64",\"result\":{\"otc_list\":[{\"ip\":\"%s\",\"port\":%d}],\"otc_test\":{\"list\":[{\"ip\":\"%s\",\"port\":%d}],\"interval\":1800,\"firsttest\":%d}}}",
			id, to_addr, to_port, to_addr, to_port, 1193);
	} else
	if (!strcasecmp(method,"props") || !strncasecmp(method,"event.",6)) {
		reply_len = 1 +
			snprintf((char *)&answer[32],
			PACKET_BUF_SIZE-16-16-16-1,
			"{\"id\":%"PRIu64",\"result\":\"ok\"}",
			id);
	} else
	if (!strcasecmp(method,"_sync.getAppData")) {
		reply_len = 1 +
			snprintf((char *)&answer[32],
			PACKET_BUF_SIZE-16-16-16-1,
			"{\"id\":%"PRIu64",\"error\":{\"code\":-6,\"message\":\"not set app data\"}}",
			id);
	} else
	if (!strcasecmp(method,"_sync.gen_presigned_url")) {
		reply_len = 1 +
			snprintf((char *)&answer[32],
			PACKET_BUF_SIZE-16-16-16-1,
			"{\"id\":%"PRIu64",\"error\":{\"code\":-7,\"message\":\"unknow device\"}}",
			id);
	} else
	if (!strcasecmp(method,"_sync.getctrycode")) {
		reply_len = 1 +
				snprintf((char *)&answer[32],
				PACKET_BUF_SIZE-16-16-16-1,
				"{\"id\":%"PRIu64",\"result\":{\"ctry_code\":\"%s\"}}",
				id,"DE");
	} else {
		say(LOGLEVEL_QUIET,"Warning: Unknown method \'%s\' requested\n", method);
		return 0;
	}

	// Finalize reply packet
	memcpy(answer,packet,16); // Copy old header
	reply_len += 16+16+pkcs7_padding_pad_buffer(&answer[32], reply_len, PACKET_BUF_SIZE, 16); /* header + md5 + padding */
	answer[2] = reply_len >> 8;
	answer[3] = reply_len & 0xFF;
	if (verbose >= LOGLEVEL_DEBUG) {
		hexdump(answer,reply_len);
	}
	memcpy(aes_iv_temp,aes_iv,sizeof(aes_iv_temp));
	AES128_CBC_encrypt_inplace(&answer[32], reply_len-32, aes_key, aes_iv );
	md5_init(&md5_state);
	md5_append(&md5_state, &answer[0], 16);
	md5_append(&md5_state, key_str, strlen((char *)key_str));
	md5_append(&md5_state, &answer[32], reply_len-32);
	md5_finish(&md5_state, &answer[16]);
	return reply_len;
}

void print_help(void)
{
	printf("Usage: dummycloud [-h|-4|-6] [-f filename] [-k key] [-c num] [-l port] [-v [num]]\n\n");
	printf("Parameters:\n");
	printf("-4          :  Listen only on IPv4 addresses\n");
	printf("-6          :  Listen on both IPv4 and IPv6 addresses (default)\n");
	printf("-f filename :  File with encryption key (default: "DEVICE_CONF")\n");
	printf("-k key      :  Encryption key, 16 characters (default: read from file)\n");
	printf("-c num      :  Exit after num processed packets (default: 0, do not exit)\n");
	printf("-l port     :  UDP listen port (default: 8053)\n");
	printf("-v[num]     :  Increase output verbosity (default: 0)\n");
	printf("               Optional values for num: 0 quiet, 1 verbose, 2 debug\n");
	printf("-V          :  Show program version\n");
	printf("-h          :  This help text\n");
	exit(1);
}

int main(int argc, char *argv[])
{
	int fd;
	struct sockaddr_storage addr, rem_addr; /* Can contain both sockaddr_in and sockaddr_in6 */
	int res, res_answer, on = 1;
	struct msghdr msghdr;
	struct iovec vec[1];
	char cbuf[512];  /* Buffer for ancillary data */
	char to_addr[INET6_ADDRSTRLEN];
	int i, c, count = 0;
	int addr_family = AF_INET6; /* Default address family */
	uint16_t listen_port = PORT;
	uint8_t frame[PACKET_BUF_SIZE];/* Buffer for packet data */
	uint8_t answer[PACKET_BUF_SIZE]; /* Answer packet data */
	uint8_t aes_key[16];
	uint8_t aes_iv[16];
	md5_state_t md5_state;
	char device_conf[256];

	setbuf(stdout, NULL);
	setbuf(stderr, NULL);
	strncpy(device_conf,DEVICE_CONF,sizeof(device_conf)-1);

	while ((c = getopt(argc, argv, "k:hf:c:l:64Vv::")) != -1) {
		switch(c) {
			case 'k':	if (strlen(optarg)==16) {
							strncpy((char *)key_str,optarg,16);
						} else {
							say(LOGLEVEL_QUIET,"Error: Specified key must be 16 characters.\n");
							return 1;
					  	}
						break;
			case 'f':	strncpy(device_conf,optarg,sizeof(device_conf)-1);
						break;
			case 'c':	count = atoi(optarg);
						break;
			case 'l':	listen_port = atoi(optarg);
						break;
			case 'V':	printf("Version %s\n",DC_VERSION);
						return 0;
			case 'v':	if (optarg) {
							verbose = atoi(optarg);
						} else {
							verbose = 1;
						}
						break;
			case '4':	addr_family = AF_INET;
						break;
			case '6':	addr_family = AF_INET6;
						break;
			case 'h':
			default:	print_help();
		}
	}

	// Read key from file
	if (strlen((char *)key_str)==0) {
		say(LOGLEVEL_VERBOSE,"Reading key from file %s\n",device_conf);
		FILE *fp;
		char *line=NULL;
		size_t len=0;
		ssize_t read;

		fp = fopen(device_conf, "r");
		if (!fp) {
			perror(device_conf);
			return 1;
		}
		while ((read = getline(&line, &len, fp)) != -1) {
			if (read >= 21) {
				if (!memcmp(line,"key=",4)) {
					memset(&key_str, 0, sizeof(key_str));
					memcpy(&key_str,&line[4],16);
				}
			}
		}
		fclose(fp);
		if (line) free(line);	
	}

	// Check AES key format
	for (i=0;i<16;i++) {
		if (!isalnum(key_str[i])) {
			say(LOGLEVEL_QUIET,"Error: Key format must be alphanumeric.\n");
			return 1;
		}
	}

	// Calculate AES key
	md5_init(&md5_state);
	md5_append(&md5_state, key_str, strlen((char *)key_str));
	md5_finish(&md5_state, aes_key);

	// Calculate IV
	md5_init(&md5_state);
	md5_append(&md5_state, aes_key, sizeof(aes_key));
	md5_append(&md5_state, key_str, strlen((char *)key_str));
	md5_finish(&md5_state, aes_iv);

	// Packet dump?
	if (verbose == LOGLEVEL_PACKETDUMP) {
		parse_packet(sizeof(test_packet),test_packet,answer,aes_key,aes_iv,"",0);
		return 0;
	}

	// Setup UDP socket
	fd = Socket(addr_family, SOCK_DGRAM, 0);
	memset(&addr, 0, sizeof(addr));
	if (addr_family == AF_INET) {
		struct sockaddr_in *addr4 = (struct sockaddr_in *)&addr;
		addr4->sin_family = addr_family;
		addr4->sin_port   = htons(listen_port);
	} else if (addr_family == AF_INET6) {
		struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)&addr;
		addr6->sin6_family= addr_family;
		addr6->sin6_port  = htons(listen_port);
		// addr6->sin6_addr  = in6addr_any;
		// inet_pton( AF_INET6, "::", (void *)&addr6->sin6_addr.s6_addr);
	}
	if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
		perror("bind");
		return 1;
	}
	/* Socket options to get data on local destination IP */
	setsockopt(fd, SOL_IP, IP_PKTINFO, &on, sizeof(on)); /* man ip(7) */
	setsockopt(fd, IPPROTO_IPV6, IPV6_RECVPKTINFO, &on, sizeof(on)); /* man ipv6(7)*/

	// UDP receive/send loop
	while (1) {
		memset(&msghdr, 0, sizeof(msghdr));
		msghdr.msg_control = cbuf;
		msghdr.msg_controllen = sizeof(cbuf);
		msghdr.msg_iov = vec;
		msghdr.msg_iovlen = 1;
		vec[0].iov_base = frame;
		vec[0].iov_len = sizeof(frame);
		msghdr.msg_name = &rem_addr; /* Remote addr, updated on recv, used on send */
		msghdr.msg_namelen = sizeof(rem_addr);
		res = recvmsg(fd, &msghdr, 0);
		if (res == -1) break;
		if (!pktinfo_to(&msghdr,to_addr,sizeof(to_addr))) {
			say(LOGLEVEL_QUIET,"Warning: Destination address could not be determined.\n");
		} else {
			res_answer = parse_packet(res,frame,answer,aes_key,aes_iv,to_addr,listen_port);
			if (res_answer > 0) {
				vec[0].iov_base = answer;
				vec[0].iov_len = res_answer;
				sendmsg(fd, &msghdr, 0);
			}
		}
		if (count) {
			if (--count == 0) break;
		}
	}
	return 0;
}
