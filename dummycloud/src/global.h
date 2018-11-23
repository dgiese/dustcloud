#ifndef GLOBAL_H
#define GLOBAL_H

/* Exit return codes */
#define	EXIT_OK			0
#define EXIT_FAIL_MEM		1
#define EXIT_FAIL_OPTION	2
#define EXIT_FAIL_TIME		3
#define EXIT_FAIL_SOCK		100
#define EXIT_FAIL_SOCKOPT	101
#define EXIT_FAIL_IP		102
#define EXIT_FAIL_SEND		103
#define EXIT_FAIL_RECV		104
#define EXIT_FAIL_REUSEPORT	105
#define EXIT_FAIL_FILEACCESS	106

#define NANOSEC_PER_SEC 1000000000 /* 10^9 */

#endif /* GLOBAL_H */
