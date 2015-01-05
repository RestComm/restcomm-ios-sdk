/*
 * Farsight Voice+Video library - interface for creating
 * network sockets with separate local and public transport
 * addresses (in case of intermediary NATs)
 *
 * Copyright (C) 2005 Nokia Corporation
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

#ifndef __FARSIGHT_NETSOCKET_H__
#define __FARSIGHT_NETSOCKET_H__

#include <glib.h>
#include <glib-object.h>

#include <unistd.h>

#ifdef HAVE_NETINET_IN_H
#include <netinet/in.h>
#endif

#ifdef HAVE_WINSOCK2_H
#include <winsock2.h>
#endif

#ifdef HAVE_WS2TCPIP_H
#include <ws2tcpip.h>
#endif

G_BEGIN_DECLS

typedef struct _FarsightNetsocket        FarsightNetsocket;
typedef struct _FarsightNetsocketClass   FarsightNetsocketClass;

GType farsight_netsocket_get_type(void);

/* TYPE MACROS */
#define FARSIGHT_NETSOCKET_TYPE \
  (farsight_netsocket_get_type())
#define FARSIGHT_NETSOCKET(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), FARSIGHT_NETSOCKET_TYPE, FarsightNetsocket))
#define FARSIGHT_NETSOCKET_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), FARSIGHT_NETSOCKET_TYPE, FarsightNetsocketClass))
#define FARSIGHT_IS_NETSOCKET(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), FARSIGHT_NETSOCKET_TYPE))
#define FARSIGHT_IS_NETSOCKET_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), FARSIGHT_NETSOCKET_TYPE))
#define FARSIGHT_NETSOCKET_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), FARSIGHT_NETSOCKET_TYPE, FarsightNetsocketClass))

struct _FarsightNetsocketClass {
    GObjectClass parent_class;

    /* signals */
    void (*ready)               (FarsightNetsocket      *protocol);

    /* methods */
    gboolean (*map)             (FarsightNetsocket      *netsocket);
    gboolean (*available)       (FarsightNetsocket      *netsocket);
};

struct _FarsightNetsocket {
    GObject parent;
    
    /* scope/protected: 
     * ---------------- */
    
    gchar *c_addr_str;
    guint16 c_port;
    gint last_errno;
    gint sockfd;
    gint aux_sockfd;
};

/**
 * Starts the binding discovery process.
 *
 * Inputs (gobject properties):
 * - sockfd: UDP socket to use for STUN discovery
 * - aux-sockfd: for RTP/RTCP use, another UDP socket; ready-signal
 *   is not emitted until both sockets are mapped to public
 *   addresses
 * 
 * Outputs (gobject properties):
 * - contactaddr and contact-port: public contact address
 *
 * Signals:
 * - will emit "ready" when process is completed
 *
 * @return FALSE if unable to start discovery
 */
gboolean farsight_netsocket_map (FarsightNetsocket *netsocket);

/**
 * Returns TRUE if the implementation is available
 * for use (for example in the case of STUN, whether 
 * STUN server is defined and can be connected to.
 */
gboolean farsight_netsocket_available (FarsightNetsocket *netsocket);

int farsight_netsocket_errno (FarsightNetsocket *netsocket);

G_END_DECLS

#endif
