/* -*- c-file-style: "linux" -*-
 * Author: Jesper Dangaard Brouer <netoptimizer@brouer.com>, (C)2014
 * License: GPLv2
 * From: https://github.com/netoptimizer/network-testing
 *
 * Common socket related helper functions
 */
#ifndef COMMON_SOCKET_H
#define COMMON_SOCKET_H

#include <stdint.h> /* types uintXX_t */
#include <netinet/in.h> /* sockaddr_in{,6} */

#ifndef IP_PMTUDISC_OMIT
#define IP_PMTUDISC_OMIT 5
#endif

#ifndef IP_PMTUDISC_INTERFACE
#define IP_PMTUDISC_INTERFACE 4
#endif

#ifndef SO_REUSEPORT
#define SO_REUSEPORT    15
#endif

/* Wrapper functions with error handling like "Stevens" */
int Socket(int addr_family, int type, int protocol);
int Connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
int Close(int sockfd);
int Setsockopt (int fd, int level, int optname, const void *optval,
		socklen_t optlen);
int Bind(int sockfd, const struct sockaddr_storage *addr);

/* Helpers */
void setup_sockaddr(int addr_family, struct sockaddr_storage *addr,
		    char *ip_string, uint16_t port);

socklen_t sockaddr_len(const struct sockaddr_storage *sockaddr);

/* Memory alloc */
extern struct  msghdr *malloc_msghdr();
extern struct mmsghdr *malloc_mmsghdr(unsigned int array_elems);
extern struct iovec *malloc_iovec(unsigned int iov_array_elems);

#endif /* COMMON_SOCKET_H */
