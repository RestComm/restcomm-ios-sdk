/*
 * Farsight Voice+Video library - netsocket interface
 *
 * Copyright (C) 2005-2006 Nokia Corporation
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

/*
 * Status:
 *  - initial implementation ready; interface not frozen
 *
 * Todo:
 *  - urgent: convert to use f_n_discover() names for functions
 *  - add support for arbitrary transport protocols?
 *  - unhandled error case: warn if pair-port uneven
 *  - implement support for random port allocation
 *  - improve routine for searching for free adjacent port pairs
 *  - provide hints about the derived addresses (address and/or
 *    port restricted, etc)
 *
 * Design
 *  - paired-ports mode (to make life easier for RTP+RTCP)
 *  - address family (IPv4 or v6)
 *
 * Notes:
 *  - see test-netsocket.c
 *
 * References:
 *  - http://www.opengroup.org/onlinepubs/009695399/basedefs/sys/socket.h.html
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <errno.h>

#include "farsight-netsocket.h"

#if !HAVE_G_DEBUG
#include "replace_g_debug.h"
#endif

/* Signals */
enum {
    SIGNAL_READY,
    SIGNAL_LAST
};

/* props */
enum {
    PROP_0,
    PROP_LOCAL_PORT,
    PROP_CONTACT_ADDR,
    PROP_CONTACT_PORT,
    PROP_SOCKFD,
    PROP_AUX_SOCKFD
};

/* compatibility with glib < 2.4 */
#ifndef G_MININT16
#define G_MININT16 (-32768)
#endif
#ifndef G_MAXINT16
#define G_MAXINT16 (32767)
#endif
#ifndef G_MAXUINT16
#define G_MAXUINT16 (65535)
#endif

static void farsight_netsocket_class_init    (FarsightNetsocketClass    *klass);
static void farsight_netsocket_init          (FarsightNetsocket         *netsocket);
static void farsight_netsocket_finalize      (GObject             *object);

static void farsight_netsocket_set_property (GObject      *object,
					     guint         prop_id,
					     const GValue *value,
					     GParamSpec   *pspec);
static void farsight_netsocket_get_property (GObject    *object,
					     guint       prop_id,
					     GValue     *value,
					     GParamSpec *pspec);
static gboolean farsight_netsocket_map_default (FarsightNetsocket *netsocket);
static gboolean farsight_netsocket_available_default (FarsightNetsocket *netsocket);

int farsight_netsocket_errno (FarsightNetsocket *netsocket);

static GObjectClass *parent_class = NULL;
static guint farsight_netsocket_signals[SIGNAL_LAST] = { 0 };

GType
farsight_netsocket_get_type (void)
{
    static GType type = 0;

    if (type == 0) {
        static const GTypeInfo info = {
            sizeof (FarsightNetsocketClass),
            NULL,
            NULL,
            (GClassInitFunc) farsight_netsocket_class_init,
            NULL,
            NULL,
            sizeof (FarsightNetsocket),
            0,
            (GInstanceInitFunc) farsight_netsocket_init
        };

        type = g_type_register_static (G_TYPE_OBJECT,
                                       "FarsightNetsocketType",
                                       &info, 0);
    }

    return type;
}

static void
farsight_netsocket_class_init (FarsightNetsocketClass *klass)
{
    GObjectClass *gobject_class;

    gobject_class = (GObjectClass *) klass;
    parent_class = g_type_class_peek_parent (klass);

    gobject_class->finalize = farsight_netsocket_finalize;

    gobject_class->set_property = farsight_netsocket_set_property;
    gobject_class->get_property = farsight_netsocket_get_property;

    farsight_netsocket_signals[SIGNAL_READY] =
	g_signal_new ("ready",
		      G_TYPE_FROM_CLASS (klass),
		      G_SIGNAL_RUN_LAST,
		      G_STRUCT_OFFSET (FarsightNetsocketClass, ready),
		      NULL, NULL,
		      g_cclosure_marshal_VOID__VOID,
		      G_TYPE_NONE,
		      0);

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_CONTACT_ADDR,
				     g_param_spec_string ("contactaddr", "contact address",
							   "contact address",
							   NULL, G_PARAM_READABLE));

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_CONTACT_PORT,
				     g_param_spec_uint ("contactport", "contact port",
							"contact port",
							0, G_MAXUINT16, 0, G_PARAM_READABLE));

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_SOCKFD,
				     g_param_spec_int ("sockfd", "sockfd",
						       "socket fd",
						       G_MININT16, G_MAXINT16, -1, G_PARAM_READWRITE));

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_AUX_SOCKFD,
				     g_param_spec_int ("aux-sockfd", "aux-sockfd",
						       "aux. sockfd",
						       G_MININT16, G_MAXINT16, -1, G_PARAM_READWRITE));

    /* assign default methods */
    klass->map = farsight_netsocket_map_default;
    klass->available = farsight_netsocket_available_default;
}

static void
farsight_netsocket_init (FarsightNetsocket *object)
{
    FarsightNetsocket *self = FARSIGHT_NETSOCKET (object);

    self->aux_sockfd = self->sockfd = -1;
}

static void
farsight_netsocket_finalize (GObject *object)
{
    FarsightNetsocket *self = FARSIGHT_NETSOCKET (object);

    self = NULL;
}

static void
farsight_netsocket_set_property (GObject      *object, 
				 guint         prop_id,
				 const GValue *value, 
				 GParamSpec   *pspec)
{
    FarsightNetsocket *self;

    g_return_if_fail (FARSIGHT_IS_NETSOCKET (object));

    self = FARSIGHT_NETSOCKET (object);

    switch (prop_id) {
       case PROP_SOCKFD: 
	   self->sockfd = g_value_get_int(value);
	   g_debug("Setting sockfd to %d.", self->sockfd);
	   break;
       case PROP_AUX_SOCKFD: 
	   self->aux_sockfd = g_value_get_int(value);
	   g_debug("Setting aux-sockfd to %d.", self->aux_sockfd);
	   break;
       default:
	   g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
    }
}

static void
farsight_netsocket_get_property (GObject    *object, 
				 guint       prop_id, 
				 GValue     *value,
				 GParamSpec *pspec)
{
    FarsightNetsocket *self;

    g_return_if_fail (FARSIGHT_IS_NETSOCKET (object));

    self = FARSIGHT_NETSOCKET (object);

    switch (prop_id) {
        case PROP_CONTACT_PORT: 
	    g_value_set_uint(value, self->c_port);
	    break;
        case PROP_CONTACT_ADDR: 
	    /* note: return local addr if same as contact addr */
	    g_value_set_string(value, self->c_addr_str);
	    break;
        case PROP_SOCKFD: 
	    g_value_set_int(value, self->sockfd);
	    break;
        case PROP_AUX_SOCKFD: 
	    g_value_set_int(value, self->aux_sockfd);
	    break;
        default:
	    g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
    }
}

gboolean farsight_netsocket_map (FarsightNetsocket *self)
{
    return FARSIGHT_NETSOCKET_GET_CLASS (self)->map (self);
}

gboolean farsight_netsocket_available (FarsightNetsocket *self)
{
    return FARSIGHT_NETSOCKET_GET_CLASS (self)->available (self);
}

static gboolean farsight_netsocket_map_default (FarsightNetsocket *netsocket)
{
    return FALSE;
}

static gboolean farsight_netsocket_available_default (FarsightNetsocket *netsocket)
{
    return FALSE;
}

int farsight_netsocket_errno (FarsightNetsocket *netsocket)
{
  return netsocket->last_errno;
}
