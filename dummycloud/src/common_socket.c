/* -*- c-file-style: "linux" -*-
 * Author: Jesper Dangaard Brouer <netoptimizer@brouer.com>, (C)2014
 * License: GPLv2
 * From: https://github.com/netoptimizer/network-testing
 *
 * Common socket related helper functions
 *
 */
#define _GNU_SOURCE /* needed for struct mmsghdr and getopt.h */
#include <sys/socket.h>
#include <sys/types.h>  /* POSIX.1-2001 does not require the inclusion */
#include <sys/uio.h>    /* struct iovec */
#include <netinet/in.h> /* sockaddr_in{,6} */
#include <arpa/inet.h>  /* inet_pton(3) */
#include <unistd.h>     /* close(3) */
#include <stdio.h>      /* perror(3) and fprintf(3) */
#include <stdlib.h>     /* exit(3) */
#include <errno.h>
#include <string.h> /* memset */
#include <stdint.h> /* types uintXX_t */

#include "global.h"

extern int verbose;

/*** Helpers ***/

/* Setup a sockaddr_in{,6} depending on IPv4 or IPv6 address */
void setup_sockaddr(int addr_family, struct sockaddr_storage *addr,
		    char *ip_string, uint16_t port)
{
	struct sockaddr_in  *addr_v4; /* Pointer for IPv4 type casting */
	struct sockaddr_in6 *addr_v6; /* Pointer for IPv6 type casting */
	int res;

	/* Setup sockaddr depending on IPv4 or IPv6 address */
	if (addr_family == AF_INET6) {
		addr_v6 = (struct sockaddr_in6*) addr;
		addr_v6->sin6_family= addr_family;
		addr_v6->sin6_port  = htons(port);
		res = inet_pton(AF_INET6, ip_string, &addr_v6->sin6_addr);
	} else if (addr_family == AF_INET) {
		addr_v4 = (struct sockaddr_in*) addr;
		addr_v4->sin_family = addr_family;
		addr_v4->sin_port   = htons(port);
		res = inet_pton(AF_INET, ip_string, &(addr_v4->sin_addr));
	} else {
		fprintf(stderr, "ERROR: Unsupported addr_family\n");
		exit(EXIT_FAIL_OPTION);
	}
	if (res <= 0) {
		if (res == 0)
			fprintf(stderr,	"ERROR: IP%s \"%s\" not in presentation format\n",
				(addr_family == AF_INET6) ? "v6" : "v4", ip_string);
		else
			perror("inet_pton");
		exit(EXIT_FAIL_IP);
	}
}

/* Generic IPv{4,6} sockaddr len/ sizeof */
socklen_t sockaddr_len(const struct sockaddr_storage *sockaddr)
{
	socklen_t len_addr = 0;
	switch (sockaddr->ss_family) {
	case AF_INET:
		len_addr = sizeof(struct sockaddr_in);
		break;
	case AF_INET6:
		len_addr = sizeof(struct sockaddr_in6);
		break;
	default:
		fprintf(stderr, "ERROR: %s(): Cannot determine lenght of addr_family(%d)",
                        __func__, sockaddr->ss_family);
		exit(EXIT_FAIL_SOCK);
	}
	return len_addr;
}

/* Wrapper functions with error handling, for basic socket function, that
 * checks the error codes, and terminate the program with an error
 * msg.  This reduces code size and still do proper error checking.
 *
 * Using an uppercase letter, just like "Stevens" does.
 */

int Socket(int addr_family, int type, int protocol) {
	int n;

	if ((n = socket(addr_family, type, protocol)) < 0) {
		perror("- socket");
		exit(EXIT_FAIL_SOCK);
	}
	return n;
}

int Connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
{
	int res = connect(sockfd, addr, addrlen);

	if (res < 0) {
		fprintf(stderr, "ERROR: %s() failed (%d) errno(%d) ",
			__func__, res, errno);
		perror("- connect");
		close(sockfd);
		exit(EXIT_FAIL_SOCK);
	}
	return res;
}

int Close(int sockfd)
{
	int res = close(sockfd);

	if (res < 0) {
		fprintf(stderr, "ERROR: %s() failed (%d) errno(%d) ",
			__func__, res, errno);
		perror("- close");
		exit(EXIT_FAIL_SOCK);
	}
	return res;
}

int Setsockopt (int fd, int level, int optname, const void *optval,
		socklen_t optlen)
{
	int res = setsockopt(fd, level, optname, optval, optlen);

	if (res < 0) {
		fprintf(stderr, "ERROR: %s() failed (%d) errno(%d) ",
			__func__, res, errno);
		perror("- setsockopt");
		exit(EXIT_FAIL_SOCKOPT);
	}
	return res;
}

int Bind(int sockfd, const struct sockaddr_storage *addr) {
	socklen_t addrlen = sockaddr_len(addr);
	int res = bind(sockfd, (struct sockaddr *)addr, addrlen);

	if (res < 0) {
		fprintf(stderr, "ERROR: %s() failed (%d) errno(%d) ",
			__func__, res, errno);
		perror("- bind");
		close(sockfd);
		exit(EXIT_FAIL_SOCK);
	}
	return res;
}

/*** Memory allocation ***/

/* Allocate struct msghdr setup structure for sendmsg/recvmsg */
struct msghdr *malloc_msghdr()
{
	struct msghdr *msg_hdr;
	unsigned int msg_hdr_sz = sizeof(*msg_hdr);

	msg_hdr = malloc(msg_hdr_sz);
	if (!msg_hdr) {
		fprintf(stderr, "ERROR: %s() failed in malloc() (caller: 0x%p)\n",
			__func__, __builtin_return_address(0));
		exit(EXIT_FAIL_MEM);
	}
	memset(msg_hdr, 0, msg_hdr_sz);
	if (verbose)
		fprintf(stderr, " - malloc(msg_hdr) = %d bytes\n", msg_hdr_sz);
	return msg_hdr;
}

/* Allocate vector array of struct mmsghdr pointers for sendmmsg/recvmmsg
 *  Notice: double "m" im mmsghdr
 */
struct mmsghdr *malloc_mmsghdr(unsigned int array_elems)
{
	struct mmsghdr *mmsg_hdr_vec;
	unsigned int memsz;

	//memsz = sizeof(*mmsg_hdr_vec) * array_elems;
	memsz = sizeof(struct mmsghdr) * array_elems;
	mmsg_hdr_vec = malloc(memsz);
	if (!mmsg_hdr_vec) {
		fprintf(stderr, "ERROR: %s() failed in malloc() (caller: 0x%p)\n",
			__func__, __builtin_return_address(0));
		exit(EXIT_FAIL_MEM);
	}
	memset(mmsg_hdr_vec, 0, memsz);
	if (verbose)
		fprintf(stderr, " - malloc(mmsghdr[%d]) = %d bytes\n",
			array_elems, memsz);
	return mmsg_hdr_vec;
}

/* Allocate I/O vector array of struct iovec.
 * (The structure supports scattered payloads)
 */
struct iovec *malloc_iovec(unsigned int iov_array_elems)
{
	struct iovec  *msg_iov;      /* io-vector: array of pointers to payload data */
	unsigned int  msg_iov_memsz; /* array memory size */

	msg_iov_memsz = sizeof(*msg_iov) * iov_array_elems;
	msg_iov = malloc(msg_iov_memsz);
	if (!msg_iov) {
		fprintf(stderr, "ERROR: %s() failed in malloc() (caller: 0x%p)\n",
			__func__, __builtin_return_address(0));
		exit(EXIT_FAIL_MEM);
	}
	memset(msg_iov, 0, msg_iov_memsz);
	if (verbose)
		fprintf(stderr, " - malloc(msg_iov[%d]) = %d bytes\n",
			iov_array_elems, msg_iov_memsz);
	return msg_iov;
}
