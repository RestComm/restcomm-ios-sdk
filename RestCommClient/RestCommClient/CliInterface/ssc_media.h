/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005 Nokia Corporation.
 *
 * Contact: Pekka Pessi <pekka.pessi@nokia.com>
 *
 * * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA
 *
 */

/**@file ssc_media.h Interface towards media subsystem
 *
 * @author Kai Vehmanen <Kai.Vehmanen@nokia.com>
 */

#ifndef HAVE_SSC_MEDIA_H
#define HAVE_SSC_MEDIA_H

#include <glib.h>
#include <glib-object.h>

#include <sofia-sip/sdp.h>

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

/**
 * Default RTP port range start value for RTP.
 */
#define SSC_MEDIA_RTP_PORT_RANGE_START 16384

enum SscMediaState {
  sm_init = 0,     /**< Media setup ongoing */      
  sm_local_ready,  /**< Local resources are set up */
  sm_active,       /**< Media send/recv active */
  sm_error,        /**< Error state has been noticed, client has to call
		        ssc_media_deactivate() */
  sm_disabled
};

typedef struct _SscMedia        SscMedia;
typedef struct _SscMediaClass   SscMediaClass;

GType ssc_media_get_type(void);

/* TYPE MACROS */
#define SSC_MEDIA_TYPE \
  (ssc_media_get_type())
#define SSC_MEDIA(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), SSC_MEDIA_TYPE, SscMedia))
#define SSC_MEDIA_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), SSC_MEDIA_TYPE, SscMediaClass))
#define SSC_IS_MEDIA(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), SSC_MEDIA_TYPE))
#define SSC_IS_MEDIA_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), SSC_MEDIA_TYPE))
#define SSC_MEDIA_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), SSC_MEDIA_TYPE, SscMediaClass))


struct _SscMediaClass {
  GObjectClass parent_class;

  /* signals 
   * ------- */

  /**
   * A signal emitted whenever the SscMedia's internal state is
   * changed. 
   *
   * @see ssc_media_state();
   * @see enum SscMediaState
   */
  void (*state_changed)               (SscMedia      *sscm, guint state);

  /* methods 
   * ------- */

  /**
   * Returns description of static capabilities
   * of the media subsystem (codecs, media, and 
   * network transports the subsystem could support).
   *
   * The result is a malloc()'ed string, stored to 'dest'. 
   *
   * @param self self pointers
   * @param dest where to store pointer to the caps SDP
   */
  int (*static_capabilities)     (SscMedia   *sscm, char **dest);

  /**
   * Activates the media subsystem. Causes devices (audio, video) to 
   * be opened, and reserving network addresses.
   *
   * @return zero on success
   */
  int (*activate)                (SscMedia   *sscm);

  /**
   * Refresh media configuration based on local and remote 
   * SDP configuration.
   *
   * @return zero on success
   */
  int (*refresh)                 (SscMedia   *sscm);

  /**
   * Deactivates the media subsystem.
   * 
   * @pre is_activate() != TRUE
   * @post is_activate() == TRUE
   */
  int (*deactivate)              (SscMedia   *sscm);

  /* turn into property 
   * ------------------ */ 

  /* - preferences: stun, audio in, audio out */
};

struct _SscMedia {
  GObject parent;
    
  /* scope/protected: 
   * ---------------- */

  int           sm_state;

  su_home_t    *sm_home;

  sdp_parser_t *sm_sdp_local;
  sdp_parser_t *sm_sdp_remote;
  gchar        *sm_sdp_local_str;    /**< remote SDP, parsed */
  gchar        *sm_sdp_remote_str;   /**< remote SDP, raw text */

  char         *sm_ad_input_type;
  char         *sm_ad_input_device;
  char         *sm_ad_output_type;
  char         *sm_ad_output_device;
};

int ssc_media_activate(SscMedia *sscm);
int ssc_media_deactivate(SscMedia *sscm);
int ssc_media_refresh(SscMedia *sscm);
int ssc_media_static_capabilities(SscMedia *sscm, char **dest);
int ssc_media_state(SscMedia *sscm);
gboolean ssc_media_is_active(SscMedia *sscm);
gboolean ssc_media_is_initialized(SscMedia *sscm);
void ssc_media_set_remote_to_local(SscMedia *self);
void ssc_media_set_local_to_caps(SscMedia *sscm);

/* Helper Routines for subclasses */
/* ------------------------------ */

void ssc_media_signal_state_change(SscMedia *sscm, enum SscMediaState state);

#endif /* HAVE_SSC_MEDIA_H */

