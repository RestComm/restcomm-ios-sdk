/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2006 Nokia Corporation.
 *
 * Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
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

/*
 * Status:
 *  - nop
 *
 * Todo:
 *  - see comments marked with 'XXX'
 *
 * Notes:
 *  - see test-sscm.c
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

#include <glib.h>
#include <sofia-sip/sdp.h>

#include "ssc_media.h"
#include "sdp_utils.h"

#if !HAVE_G_DEBUG
#include "replace_g_debug.h"
#endif

/* Signals */
enum {
  SIGNAL_STATE,
  SIGNAL_LAST
};

/* props */
enum {
  PROP_0,
  PROP_LOCAL_SDP,
  PROP_REMOTE_SDP,
  PROP_AUDIO_INPUT,
  PROP_AUDIO_OUTPUT,
};

static void ssc_media_class_init    (SscMediaClass    *klass);
static void ssc_media_init          (SscMedia         *sscm);
static void ssc_media_finalize      (GObject             *object);

static void ssc_media_set_property (GObject      *object,
				    guint         prop_id,
				    const GValue *value,
				    GParamSpec   *pspec);
static void ssc_media_get_property (GObject    *object,
				    guint       prop_id,
				    GValue     *value,
				    GParamSpec *pspec);

static int priv_activate_base(SscMedia *sscm);
static int priv_deactivate_base(SscMedia *sscm);
static int priv_refresh_base(SscMedia *sscm);
static int priv_static_capabilities_base(SscMedia *sscm, char **dest);
static int priv_set_local_sdp(SscMedia *self, const gchar *str);
static int priv_set_remote_sdp(SscMedia *self, const gchar *str);

static GObjectClass *parent_class = NULL;
static guint ssc_media_signals[SIGNAL_LAST] = { 0 };

GType
ssc_media_get_type (void)
{
  static GType type = 0;
  
  if (type == 0) {
    static const GTypeInfo info = {
      sizeof (SscMediaClass),
      NULL,
      NULL,
      (GClassInitFunc) ssc_media_class_init,
      NULL,
      NULL,
      sizeof (SscMedia),
      0,
      (GInstanceInitFunc) ssc_media_init
    };
    
    type = g_type_register_static (G_TYPE_OBJECT,
				   "SscMediaType",
				   &info, 0);
  }
  
  return type;
}

static void
ssc_media_class_init (SscMediaClass *klass)
{
  GObjectClass *gobject_class;
  
  g_debug("%s:%d", __func__, __LINE__);
  
  gobject_class = (GObjectClass *) klass;
  parent_class = g_type_class_peek_parent (klass);
  
  gobject_class->finalize = ssc_media_finalize;
  gobject_class->set_property = ssc_media_set_property;
  gobject_class->get_property = ssc_media_get_property;

  ssc_media_signals[SIGNAL_STATE] =
    g_signal_new ("state-changed",
		  G_TYPE_FROM_CLASS (klass),
		  G_SIGNAL_RUN_LAST,
		  G_STRUCT_OFFSET (SscMediaClass, state_changed),
		  NULL, NULL,
		  g_cclosure_marshal_VOID__UINT,
		  G_TYPE_NONE, 
		  1,
		  G_TYPE_UINT,
		  0);

  /* property: local_sdp */
  g_object_class_install_property(G_OBJECT_CLASS(klass),
				  PROP_LOCAL_SDP,
				  g_param_spec_string("localsdp", "Local SDP", "Set local SDP.", NULL, G_PARAM_READWRITE));

  /* property: remote_sdp */
  g_object_class_install_property(G_OBJECT_CLASS(klass),
				  PROP_REMOTE_SDP,
				  g_param_spec_string("remotesdp", "Remote SDP", "Set remote SDP.", NULL, G_PARAM_READWRITE));

  /* assign default methods */
  klass->activate = priv_activate_base;
  klass->deactivate = priv_deactivate_base;
  klass->refresh = priv_refresh_base;
  klass->static_capabilities = priv_static_capabilities_base;
}

static void
ssc_media_init (SscMedia *object)
{
  SscMedia *self = SSC_MEDIA (object);

  self->sm_home = su_home_new(sizeof (*self->sm_home));

  g_debug("%s:%d", __func__, __LINE__);
}

static void
ssc_media_finalize (GObject *object)
{
  SscMedia *self = SSC_MEDIA (object);

  su_home_unref(self->sm_home);

  g_debug("%s:%d", __func__, __LINE__);
}

static void
ssc_media_set_property (GObject      *object, 
			guint         prop_id,
			const GValue *value, 
			GParamSpec   *pspec)
{
  SscMedia *self;
  int res = 0;
  g_return_if_fail (SSC_IS_MEDIA (object));

  self = SSC_MEDIA (object);

  switch (prop_id) {
  case PROP_LOCAL_SDP: 
    res = priv_set_local_sdp(self, g_value_get_string (value));
    /* note: succesfully set new l-SDP, update the media config */
    if (!res && ssc_media_is_initialized(self))
      ssc_media_refresh(self);
    break;
  case PROP_REMOTE_SDP: 
    res = priv_set_remote_sdp(self, g_value_get_string (value));
    /* note: succesfully set new r-SDP, update the media config */
    if (!res && ssc_media_is_initialized(self))
      ssc_media_refresh(self);
    break;
  default:
    g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
  }
}

static void
ssc_media_get_property (GObject    *object, 
			guint       prop_id, 
			GValue     *value,
			GParamSpec *pspec)
{
  SscMedia *self;

  g_return_if_fail (SSC_IS_MEDIA (object));

  self = SSC_MEDIA (object);

  switch (prop_id) {
  case PROP_LOCAL_SDP:
    if (!self->sm_sdp_local_str) {
      sdp_print_to_text(self->sm_home, self->sm_sdp_local, &self->sm_sdp_local_str);
    }
    g_value_set_string (value, self->sm_sdp_local_str);
    break;
  case PROP_REMOTE_SDP: 
    if (!self->sm_sdp_remote_str) {
      sdp_print_to_text(self->sm_home, self->sm_sdp_remote, &self->sm_sdp_remote_str);
    }
    g_value_set_string (value, self->sm_sdp_remote_str);
    break;
  default:
    g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
  }
}

/**
 * Media subsystem is currently active (media is
 * transferred).
 */
gboolean ssc_media_is_active(SscMedia *sscm)
{
  return sscm->sm_state == sm_active;
}

/**
 * Media subsystem state is either initializing,
 * active, or in error.
 */
gboolean ssc_media_is_initialized(SscMedia *sscm)
{
  return sscm->sm_state != sm_disabled;
}

static int priv_activate_base(SscMedia *sscm)
{
  SscMedia *parent = SSC_MEDIA(sscm);
  g_message("Activating dummy media implementation.");
  if (sscm->sm_sdp_local == NULL) {
    sdp_session_t *l_sdp;

    ssc_media_set_local_to_caps(sscm);

    l_sdp = sdp_session(sscm->sm_sdp_local);

    /* set port to 16384 */
    if (l_sdp && l_sdp->sdp_media) {
      l_sdp->sdp_media->m_port = SSC_MEDIA_RTP_PORT_RANGE_START;
      if (sscm->sm_sdp_local_str) 
	g_free(sscm->sm_sdp_local_str), sscm->sm_sdp_local_str = NULL;
    }
  }
  if (sscm->sm_sdp_remote == NULL) {
    /* remote SDP not yet known, create a dummy one from 
     * our own SDP */
    ssc_media_set_remote_to_local(sscm);
  }

  ssc_media_signal_state_change (sscm, sm_active);
  return 0;
}

static int priv_refresh_base(SscMedia *sscm)
{
  g_message("Refreshing dummy media implementation state.");
  return 0;
}

static int priv_deactivate_base(SscMedia *sscm)
{
  g_message("Deactivating dummy media implementation.");
  sscm->sm_state = sm_disabled;
  return 0;
}

static int priv_set_local_sdp(SscMedia *self, const gchar *str)
{
  su_home_t *home = self->sm_home;
  const char *pa_error;
  int res = 0;

  g_debug(__func__);

  if (self->sm_sdp_local)
    sdp_parser_free(self->sm_sdp_local);

  /* XXX: only update if SDP has really changed */
  /* g_message("parsing SDP:\n%s\n---", str); */

  self->sm_sdp_local = sdp_parse(home, str, strlen(str), sdp_f_insane);
  pa_error = sdp_parsing_error(self->sm_sdp_local);
  if (pa_error) {
    g_warning("%s: error parsing SDP: %s\n", __func__, pa_error);
    res = -1;
  }
  else {
    if (self->sm_sdp_local_str) 
      g_free(self->sm_sdp_local_str), self->sm_sdp_local_str = NULL;
  }

  return res;

}

static int priv_set_remote_sdp(SscMedia *self, const gchar *str)
{
  su_home_t *home = self->sm_home;
  const char *pa_error;
  int res = 0, dlen = strlen(str);

  g_debug(__func__);

  if (self->sm_sdp_remote)
    sdp_parser_free(self->sm_sdp_remote);

  /* XXX: only update if SDP has really changed */
  /* g_message("parsing SDP:\n%s\n---", str); */

  self->sm_sdp_remote = sdp_parse(home, str, dlen, sdp_f_insane);
  pa_error = sdp_parsing_error(self->sm_sdp_remote);
  if (pa_error) {
    g_warning("%s: error parsing SDP: %s\n", __func__, pa_error);
    res = -1;
  }
  else {
    if (self->sm_sdp_remote_str) 
      g_free(self->sm_sdp_remote_str);
  }

  return res;
}

static int priv_static_capabilities_base(SscMedia *sscm, char **dest)
{
  if (dest)
    *dest = g_strdup("v=0\nm=audio 0 RTP/AVP 0\na=rtpmap:0 PCMU/8000");

  return 0;
}

int ssc_media_activate(SscMedia   *self)
{
  return SSC_MEDIA_GET_CLASS (self)->activate (self);
}

int ssc_media_deactivate(SscMedia   *self)
{
  return SSC_MEDIA_GET_CLASS (self)->deactivate (self);
}

int ssc_media_refresh(SscMedia *self)
{
  return SSC_MEDIA_GET_CLASS (self)->refresh (self);
}

int ssc_media_static_capabilities(SscMedia *self, char **dest)
{
  return SSC_MEDIA_GET_CLASS (self)->static_capabilities (self, dest);
}

int ssc_media_state(SscMedia *sscm)
{
  return sscm->sm_state;
}

void ssc_media_set_local_to_caps(SscMedia *self)
{
  gchar *tmp_str = NULL;

  ssc_media_static_capabilities(self, &tmp_str);
  printf("Set local SDP based on capabilities: %s\n", tmp_str);

  g_object_set(G_OBJECT(self), 
	       "localsdp", tmp_str, NULL);

  free(tmp_str);
}

/**
 * Initialize the remote SDP description with
 * contents of the local SDP.
 */
void ssc_media_set_remote_to_local(SscMedia *self)
{
  sdp_session_t *sdp;
  sdp_media_t *media;
  gchar *tmp_str = NULL;

  g_assert(G_IS_OBJECT(self));

  g_object_get(G_OBJECT(self),
	       "localsdp", &tmp_str, NULL);

  printf("Set remote SDP based on capabilities: %s\n", tmp_str);

  if (tmp_str) 
    g_object_set(G_OBJECT(self),
		 "remotesdp", tmp_str, NULL);

  /* note: zero out ports for all media */
  if (self->sm_sdp_remote) {
    sdp = sdp_session(self->sm_sdp_remote);
    if (sdp) {
      for(media = sdp->sdp_media; media; media = media->m_next) {
	media->m_port = 0;
      }
    }
  }
}

void ssc_media_signal_state_change(SscMedia *sscm, enum SscMediaState state)
{
  if (sscm->sm_state != state) {
    printf ("Signaling media subsystem change from %u to %u.\n", sscm->sm_state, state);
    sscm->sm_state = state;
    g_signal_emit_by_name(G_OBJECT(sscm), "state-changed", state, NULL); 
  }
}
