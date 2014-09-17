/*
 * Farsight Voice+Video library - STUN socket interface
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

#ifndef __FARSIGHT_NETSOCKET_STUN_H__
#define __FARSIGHT_NETSOCKET_STUN_H__

#include <glib.h>
#include <glib-object.h>

#include "farsight-netsocket.h"

G_BEGIN_DECLS

typedef struct _FarsightNetsocketStun        FarsightNetsocketStun;
typedef struct _FarsightNetsocketStunClass   FarsightNetsocketStunClass;

GType farsight_netsocket_stun_get_type(void);

/* TYPE MACROS */
#define FARSIGHT_NETSOCKET_STUN_TYPE \
  (farsight_netsocket_stun_get_type())
#define FARSIGHT_NETSOCKET_STUN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), FARSIGHT_NETSOCKET_STUN_TYPE, FarsightNetsocketStun))
#define FARSIGHT_NETSOCKET_STUN_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), FARSIGHT_NETSOCKET_STUN_TYPE, FarsightNetsocketStunClass))
#define FARSIGHT_IS_NETSOCKET_STUN(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), FARSIGHT_NETSOCKET_STUN_TYPE))
#define FARSIGHT_IS_NETSOCKET_STUN_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), FARSIGHT_NETSOCKET_STUN_TYPE))
#define FARSIGHT_NETSOCKET_STUN_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), FARSIGHT_NETSOCKET_STUN_TYPE, FarsightNetsocketStunClass))

#define SU_ROOT_MAGIC  FarsightNetsocketStun
#define STUN_MAGIC_T   FarsightNetsocketStun
#define STUN_DISCOVERY_MAGIC_T   FarsightNetsocketStun

#include <sofia-sip/su_source.h>
#include <sofia-sip/stun.h>
#include <sofia-sip/stun_tag.h>

struct _FarsightNetsocketStunClass {
    FarsightNetsocketClass parent_class;
};

struct _FarsightNetsocketStun {
    FarsightNetsocket parent;
    
    /* scope/private: 
     * -------------- */
    
    su_root_t *root;
    stun_handle_t *stunh;
    gchar *stun_domain;
    gchar *stun_server;
    gboolean strict_msgint;
    gboolean dispose_run;
    int tls_socket;
};

G_END_DECLS

#endif
