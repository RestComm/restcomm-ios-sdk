/*
 * Farsight Voice+Video library - STUN socket interface
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
 *  - XXX
 *
 * Todo:
 *  - add support for configuration properties (domain, msgint, stun-server)
 *  - add support for querying if STUN is available for use (the
 *    "available" method
 *
 * Notes:
 *  - see farsight/tests/test-netsocket.c
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <errno.h>

#include "farsight-netsocket-stun.h"

#if !HAVE_G_DEBUG
#include "replace_g_debug.h"
#endif

/* props */
enum {
    PROP_0,
    PROP_STUN_DOMAIN,
    PROP_STUN_SERVER,
    PROP_STRICT_MSGINT
};

static void farsight_netsocket_stun_class_init    (FarsightNetsocketStunClass    *klass);
static void farsight_netsocket_stun_init          (FarsightNetsocketStun         *netsocket);
static void farsight_netsocket_stun_dispose       (GObject             *object);
static void farsight_netsocket_stun_finalize      (GObject             *object);

static void farsight_netsocket_stun_set_property (GObject      *object,
					     guint         prop_id,
					     const GValue *value,
					     GParamSpec   *pspec);
static void farsight_netsocket_stun_get_property (GObject    *object,
					     guint       prop_id,
					     GValue     *value,
					     GParamSpec *pspec);
static gboolean farsight_netsocket_stun_map (FarsightNetsocket *netsocket);

static void cb_stun_state(stun_magic_t *magic,
			  stun_handle_t *en,
			  stun_discovery_t *sd,
			  stun_action_t action,
			  stun_state_t event);

static FarsightNetsocketClass *parent_class = NULL;

GType
farsight_netsocket_stun_get_type (void)
{
    static GType type = 0;

    if (type == 0) {
        static const GTypeInfo info = {
            sizeof (FarsightNetsocketStunClass),
            NULL,
            NULL,
            (GClassInitFunc) farsight_netsocket_stun_class_init,
            NULL,
            NULL,
            sizeof (FarsightNetsocketStun),
            0,
            (GInstanceInitFunc) farsight_netsocket_stun_init
        };

        type = g_type_register_static (FARSIGHT_NETSOCKET_TYPE,
                                       "FarsightNetsocketStunType",
                                       &info, 0);
    }

    return type;
}

static void
farsight_netsocket_stun_class_init (FarsightNetsocketStunClass *klass)
{
    GObjectClass *gobject_class;
    FarsightNetsocketClass *farsightnetsocket_class;

    gobject_class = (GObjectClass *) klass;
    parent_class = g_type_class_ref (FARSIGHT_NETSOCKET_TYPE);
    farsightnetsocket_class = FARSIGHT_NETSOCKET_CLASS(klass);

    gobject_class->dispose = farsight_netsocket_stun_dispose;
    gobject_class->finalize = farsight_netsocket_stun_finalize;
    gobject_class->set_property = farsight_netsocket_stun_set_property;
    gobject_class->get_property = farsight_netsocket_stun_get_property;

    /* reimplement base class methods */
    farsightnetsocket_class->map = farsight_netsocket_stun_map;

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_STUN_DOMAIN,
				     g_param_spec_string ("domain", "Domain for STUN server",
							  "Domain used to discover STUN server address",
							  NULL, G_PARAM_READWRITE));

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_STUN_SERVER,
				     g_param_spec_string ("server", "STUN server address",
							  "STUN server addresses; hostname or IP",
							   NULL, G_PARAM_READWRITE));

    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_STRICT_MSGINT,
				     g_param_spec_boolean ("strict-msgint", "Require message integrity checks",
							   "Whether to require message integrity checks to be performed",
							   FALSE, G_PARAM_READWRITE));


}

static void
farsight_netsocket_stun_init (FarsightNetsocketStun *object)
{
    FarsightNetsocketStun *self = FARSIGHT_NETSOCKET_STUN (object);
    GSource *gsource;

    /* create a su event loop and connect it to glib */
    su_init();
    self->root = su_root_source_create(self);
    su_root_threading(self->root, 1);
    gsource = su_root_gsource(self->root);
    g_source_attach(gsource, NULL);

    self->dispose_run = FALSE;
}

/** 
 * First part of object destruction.
 */
static void
farsight_netsocket_stun_dispose (GObject *object)
{
  FarsightNetsocketStun *self = FARSIGHT_NETSOCKET_STUN (object);

  if (!self->dispose_run) {
    self->dispose_run = TRUE;
    /* XXX: detach gsource, unref su_root */
    if (self->stunh) {
       stun_handle_destroy(self->stunh), self->stunh = NULL;
       /* note: release of parent->sockfd is done either on error, or in the
	  stun library callback */
    }
  }
}

/**
 * Second part of object destruction.
 */
static void
farsight_netsocket_stun_finalize (GObject *object)
{
    FarsightNetsocketStun *self = FARSIGHT_NETSOCKET_STUN (object);

    self = NULL;
}

static void
farsight_netsocket_stun_set_property (GObject      *object, 
				      guint         prop_id,
				      const GValue *value, 
				      GParamSpec   *pspec)
{
    FarsightNetsocketStun *self;
  
    g_return_if_fail (FARSIGHT_IS_NETSOCKET_STUN (object));
    self = FARSIGHT_NETSOCKET_STUN (object);
  
    switch (prop_id) {
        case PROP_STUN_DOMAIN: 
	  g_free(self->stun_domain);
	  self->stun_domain = g_strdup(g_value_get_string (value)); 
	  break;
      
        case PROP_STUN_SERVER: 
	  g_free(self->stun_server);
	  self->stun_server = g_strdup(g_value_get_string (value)); 
	  break;
	  
        case PROP_STRICT_MSGINT: 
	  self->strict_msgint = g_value_get_boolean (value); 
          break;
	  
        default:
	  g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
    }
}

static void
farsight_netsocket_stun_get_property (GObject    *object, 
				      guint       prop_id, 
				      GValue     *value,
				      GParamSpec *pspec)
{
    FarsightNetsocketStun *self;

    g_return_if_fail (FARSIGHT_IS_NETSOCKET_STUN (object));

    self = FARSIGHT_NETSOCKET_STUN (object);

    switch (prop_id) {
        case PROP_STUN_DOMAIN: 
	    g_value_set_string(value, self->stun_domain);
	    break;
        case PROP_STUN_SERVER: 
	    g_value_set_string(value, self->stun_server);
	    break;
        case PROP_STRICT_MSGINT: 
	    /* note: return local addr if same as contact addr */
	    g_value_set_boolean(value, self->strict_msgint);
	    break;
        default:
	    g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
    }
}

static gboolean farsight_netsocket_stun_map (FarsightNetsocket *netsocket)
{
    FarsightNetsocketStun *self = FARSIGHT_NETSOCKET_STUN (netsocket);
    FarsightNetsocket *parent = FARSIGHT_NETSOCKET(self);
    gboolean res = TRUE;
    int stun_res = 0;

    g_return_val_if_fail(parent->sockfd != -1, FALSE);

    g_debug("%s", __func__);

    g_debug("server:%s domain:%s.", self->stun_server, self->stun_domain);

    self->stunh = stun_handle_init(self->root,
				   TAG_IF(self->stun_server, 
					  STUNTAG_SERVER(self->stun_server)),
				   TAG_IF(self->stun_domain, 
					  STUNTAG_DOMAIN(self->stun_domain)),
				   TAG_NULL()); 
    

    if (self->stunh) {
	stun_res = stun_obtain_shared_secret(self->stunh,
					     cb_stun_state, 
					     self,
					     TAG_NULL());
	
	if (stun_res < 0) {
	    if (self->strict_msgint) {
		res = FALSE;
		stun_handle_destroy(self->stunh), self->stunh = NULL;
		g_debug("STUN shared-secret request failed, unable to use STUN (strict msgint mode).");
	    }
	    else {
		if (stun_bind(self->stunh, cb_stun_state, self, 
			      STUNTAG_SOCKET(parent->sockfd), 
			      STUNTAG_REGISTER_EVENTS(1),
			      TAG_NULL()) < 0) {
		    res = FALSE;
		    stun_handle_destroy(self->stunh), self->stunh = NULL;
		    g_debug("Failed to start stun_bind().");
		}
	    }
	}
    }
    else {
	res = FALSE;
	g_debug("Failed to start connection to a STUN server.");
    }

    return res;
}

static void cb_stun_state(stun_magic_t *magic,
			  stun_handle_t *en,
			  stun_discovery_t *sd,
			  stun_action_t action,
			  stun_state_t event)
{
    FarsightNetsocketStun *self = FARSIGHT_NETSOCKET_STUN(magic);
    FarsightNetsocket *parent = FARSIGHT_NETSOCKET(self);
    su_sockaddr_t sa;
    socklen_t salen = sizeof(sa);
    const su_addrinfo_t *ai = stun_server_address(en);
#   define CB_STUN_STATE_IPADDR 48
    char c_ipaddr[CB_STUN_STATE_IPADDR];
    const char *server_addr = NULL;
    uint16_t server_port = 0;
    int res;

    if (ai) {
      server_addr = ai->ai_canonname;
      server_port = ntohs(((struct sockaddr_in*)ai->ai_addr)->sin_port);
    }

    g_debug("%s: %s (%d)", __func__, stun_str_state(event), (int)event);
    
    switch (event) {
	
    case stun_tls_done:
	g_debug("%s: shared secret obtained over TLS", __func__);
	res = stun_bind(self->stunh, cb_stun_state, self, 
			STUNTAG_SOCKET(parent->sockfd), 
			STUNTAG_REGISTER_EVENTS(1),
			TAG_NULL());
	if (res < 0) {
	  /* note: failed bind after succesful TLS */
	  g_signal_emit_by_name(G_OBJECT(self), "ready", NULL);
	}
	break;

    case stun_tls_connection_failed:
    case stun_tls_connection_timeout:
    case stun_tls_ssl_connect_failed:
        res = 0;
	if (!self->strict_msgint) {
	    res = stun_bind(self->stunh, cb_stun_state, self, 
			    STUNTAG_SOCKET(parent->sockfd), 
			    STUNTAG_REGISTER_EVENTS(1),
			    TAG_NULL());
	}
	if (res < 0 || self->strict_msgint) {
	    /* note: failed bind after failed TLS */
	    g_signal_emit_by_name(G_OBJECT(self), "ready", NULL);
	}
        break;

    case stun_discovery_done:
	stun_discovery_get_address(sd, &sa, &salen);
	inet_ntop(sa.su_family, SU_ADDR(&sa), c_ipaddr, sizeof(c_ipaddr));
	parent->c_port = ntohs(sa.su_port);
	parent->c_addr_str = g_strndup(c_ipaddr, CB_STUN_STATE_IPADDR - 1);
	g_debug("%s: our public contact address is %s:%u (server %s:%u)\n", 
		__func__,
		parent->c_addr_str, (unsigned) parent->c_port, server_addr, server_port);
	g_debug("%s: releasing sockfd=%d from STUN", __func__, parent->sockfd);
	stun_discovery_release_socket(sd);
	/* note: emit "ready" signal from base class */
	g_signal_emit_by_name(G_OBJECT(self), "ready", NULL);
	break;

    case stun_discovery_error:
	g_debug("%s: error in STUN binding discovery", __func__);
	if (sd)
	  stun_discovery_release_socket(sd);
	g_signal_emit_by_name(G_OBJECT(self), "ready", NULL);
	break;

    case stun_discovery_timeout:
	g_debug("%s: unable to connect to STUN server", __func__);
	if (sd)
	  stun_discovery_release_socket(sd);
	g_signal_emit_by_name(G_OBJECT(self), "ready", NULL);
        break;

    case stun_error:
	g_debug("%s: error in communication with the STUN server", __func__);
	/* note: problem with STUN server, socket still valid */
	if (sd)
	  stun_discovery_release_socket(sd);
	g_signal_emit_by_name(G_OBJECT(self), "ready", NULL);
	break;
	
    default:
	break;
    }
}
