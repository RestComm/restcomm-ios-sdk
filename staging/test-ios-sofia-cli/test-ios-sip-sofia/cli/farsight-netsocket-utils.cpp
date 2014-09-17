/*
 * Farsight Voice+Video library - utils for socket creation
 *
 * Copyright (C) 2006 Nokia Corporation
 * Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <glib.h>

#include <sys/types.h>

#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif

#ifdef HAVE_WINSOCK2_H
#include <winsock2.h>
#endif

#ifdef HAVE_WS2TCPIP_H
#include <ws2tcpip.h>
#else
#include <sys/socket.h>
#endif


#if HAVE_ARPA_INET_H
#include <arpa/inet.h>
#endif
#if HAVE_NETINET_IN_H
#include <netinet/in.h> /* POSIX */
#endif

#ifndef random
#define random rand
#endif

#define FARSIGHT_NETSOCKET_PORT_SCAN_RANGE 4096

int farsight_netsocket_bind_udp_port(guint8 af, const char *l_addr_str, guint16*l_port, gboolean scan, int *aux_sockfd)
{
    int sockfd, i;
    guint16 pri_port, aux_port;
    struct sockaddr_in addr;
    gboolean pri_found = FALSE;

    g_return_val_if_fail (af == AF_INET, -1);
    g_return_val_if_fail (l_port != NULL, -1);

    /* create the socket if needed */
    sockfd = socket (af, SOCK_DGRAM, 0);

    /* pick a random port if needed */
    pri_port = *l_port;
    if (pri_port == 0) {
	pri_port = (random() % (65535 - 1023)) + 1023;
	fprintf(stderr, "Selected random start port of %u.\n", pri_port);
    }
    
    /* loop until available port, or port pair, is found */
    for (i = 0; pri_found != TRUE && i < FARSIGHT_NETSOCKET_PORT_SCAN_RANGE; i++) {
	int ret = 0;

	pri_found = FALSE;

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = af;
	addr.sin_port = htons (pri_port);

	if (l_addr_str != NULL)
	    inet_pton(af, l_addr_str, &addr.sin_addr);
	else
	    addr.sin_addr.s_addr = INADDR_ANY;

	ret = bind(sockfd, (struct sockaddr*)&addr, sizeof(addr));
	if (ret == 0) {
	    fprintf(stderr, "Succesfully bound to local port %d.\n", pri_port);
	    *l_port = pri_port;
	    pri_found = TRUE;
	} else {
	    perror("bind()");
	    fprintf(stderr, "Unable to bind to local port %d (%d).\n", pri_port, ret);
	}
	
	if (pri_found == TRUE && aux_sockfd) {
	    /* step: try to allocate and bind the paired port */
	    int tmp_sockfd = socket (af, SOCK_DGRAM, 0);
	    aux_port = pri_port + 1;
	    addr.sin_family = af;
	    addr.sin_port = htons (aux_port);
	    ret = bind(tmp_sockfd, (struct sockaddr*)&addr, sizeof(addr));
	    if (ret == 0) {
		fprintf(stderr, "Succesfully bound to local aux port %d.\n", aux_port);
		*aux_sockfd = tmp_sockfd;
		break;
	    } else {
		/* step: failure, restart */
	        perror("bind()");
		fprintf(stderr, "Unable to bind to local aux port %d (%d).\n", aux_port + 1, ret);
		pri_found = FALSE;

		close(tmp_sockfd);
		close(sockfd), sockfd = -1;
	    }
	}
	
	if (scan != TRUE) 
	    break;

	pri_port = (pri_port + 2) % ((65535 - 1023) + 1023);
    }

    /* could not bind to a primary port */
    if (pri_found != TRUE) {
      close(sockfd);
      sockfd = -1;
    }

    return sockfd;
}
