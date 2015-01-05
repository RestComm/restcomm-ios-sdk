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

/**
 * Creates and binds to the given UDP port.
 *
 * To get RFC3550 compliant pair for RTP/RCTP, select an
 * even 'l_port', define 'aux_sockfd', and enable scanning.
 * 
 * @param af - AF_INET, AF_INET6, ... (POSIX: sys/socket.h)
 * @param l_addr_str - local interface to bind to, or NULL for any
 * @param l_port - local port (0 = select random free port) [IN/OUT]
 * @param scan - whether to scan for other available ports if l_port
 *        is already taken
 * @param aux_sockfd - (it non-NULL, allocate a paired port of
 *        l_port plus 1) [IN/OUT]
 *
 * @return -1 on error, otherwise the socket handle
 */
int farsight_netsocket_bind_udp_port(guint8 af, const char *l_addr_str, guint16*l_port, gboolean scan, int *aux_sockfd);
