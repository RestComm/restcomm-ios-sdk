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
 *  - not yet working
 *  - udpsink does not support 'sockfd' but requires 
 *    dest:port to be added to the packets 'dynudpsink'
 *
 * Notes:
 *  - ...
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_GST

#include <assert.h>
#include <stdio.h>
#include <errno.h>

#include <gst/gst.h>

#include "sdp_utils.h"
#include "ssc_media_gst.h"
#include "ssc_media_gst_utils.h"
#include "farsight-netsocket-stun.h"
#include "farsight-netsocket-utils.h"

#if !HAVE_G_DEBUG
#include "replace_g_debug.h"
#endif

/* Signals */
enum {
  SIGNAL_LAST
};

/* props */
enum {
  PROP_LAST, 
  PROP_AUDIO_INPUT_TYPE,
  PROP_AUDIO_INPUT_DEVICE,
  PROP_AUDIO_OUTPUT_TYPE,
  PROP_AUDIO_OUTPUT_DEVICE,
  PROP_STUN_SERVER,
  PROP_STUN_DOMAIN
};

static void ssc_media_gst_class_init    (SscMediaGstClass *klass);
static void ssc_media_gst_init          (SscMediaGst *sscm);
static void ssc_media_gst_dispose       (GObject *object);
static void ssc_media_gst_finalize      (GObject *object);

static void ssc_media_gst_set_property (GObject      *object,
					guint         prop_id,
					const GValue *value,
					GParamSpec   *pspec);
static void ssc_media_gst_get_property (GObject    *object,
					guint       prop_id,
					GValue     *value,
					GParamSpec *pspec);

static int priv_activate_gst(SscMedia *sscm);
static int priv_deactivate_gst(SscMedia *sscm);
static int priv_refresh_gst(SscMedia *sscm);
static int priv_static_capabilities_gst(SscMedia *sscm, char **dst);

static gboolean priv_cb_pipeline_bus (GstBus *bus, GstMessage *message, gpointer data);
static void priv_cb_ready(FarsightNetsocket *netsocket, gpointer data);
static int priv_update_rx_elements(SscMediaGst *self);
static int priv_update_tx_elements(SscMediaGst *self);
static int priv_setup_rtpelements(SscMediaGst *self);
static gboolean priv_verify_required_elements(void);

static GObjectClass *parent_class = NULL;
/* static guint ssc_media_gst_signals[SIGNAL_LAST] = { 0 }; */

GType
ssc_media_gst_get_type (void)
{
    static GType type = 0;

    if (type == 0) {
        static const GTypeInfo info = {
            sizeof (SscMediaGstClass),
            NULL,
            NULL,
            (GClassInitFunc) ssc_media_gst_class_init,
            NULL,
            NULL,
            sizeof (SscMediaGst),
            0,
            (GInstanceInitFunc) ssc_media_gst_init
        };

	if (priv_verify_required_elements()) {
	  type = g_type_register_static (SSC_MEDIA_TYPE,
					 "SscMediaGstType",
					 &info, 0);
	}
    }

    return type;
}

static void ssc_media_gst_class_init (SscMediaGstClass *klass)
{
    GObjectClass *gobject_class;
    SscMediaClass *parent_class = SSC_MEDIA_CLASS(klass);

    g_debug("%s:%d", G_STRFUNC, __LINE__);

    gobject_class = (GObjectClass *) klass;
    gobject_class->dispose = ssc_media_gst_dispose;
    gobject_class->finalize = ssc_media_gst_finalize;
    gobject_class->set_property = ssc_media_gst_set_property;
    gobject_class->get_property = ssc_media_gst_get_property;

    /* assign default methods */
    parent_class->activate = priv_activate_gst;
    parent_class->deactivate = priv_deactivate_gst;
    parent_class->refresh = priv_refresh_gst;
    parent_class->static_capabilities = priv_static_capabilities_gst;

    /* property: audio input type */
    g_object_class_install_property(G_OBJECT_CLASS(klass),
				    PROP_AUDIO_INPUT_TYPE,
				    g_param_spec_string("audio-input-type", "Audio input type", "Audio input type (gst element name).", NULL, G_PARAM_READWRITE));

    /* property: audio input device */
    g_object_class_install_property(G_OBJECT_CLASS(klass),
				    PROP_AUDIO_INPUT_DEVICE,
				    g_param_spec_string("audio-input-device", "Audio input device", "Audio input device (gst element name).", NULL, G_PARAM_READWRITE));

    /* property: audio output type */
    g_object_class_install_property(G_OBJECT_CLASS(klass),
				    PROP_AUDIO_OUTPUT_TYPE,
				    g_param_spec_string("audio-output-type", "Audio output type", "Audio output type (gst element name).", NULL, G_PARAM_READWRITE));

    /* property: audio output device */
    g_object_class_install_property(G_OBJECT_CLASS(klass),
				    PROP_AUDIO_OUTPUT_DEVICE,
				    g_param_spec_string("audio-output-device", "Audio output device", "Audio output device (gst element name).", NULL, G_PARAM_READWRITE));
    
    /* property: STUN server */
    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_STUN_SERVER,
				     g_param_spec_string ("stun-server", "STUN server address",
							  "STUN server addresses; hostname or IP",
							   NULL, G_PARAM_READWRITE));

    /* property: STUN domain */
    g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_STUN_DOMAIN,
				     g_param_spec_string ("stun-domain", "STUN domain address",
							  "domain for STUN DNS-SRV lookup",
							   NULL, G_PARAM_READWRITE));

}

static gboolean priv_verify_required_elements(void)
{
  static char *ssc_gst_elements[] = { "mulawenc", "mulawdec", "udpsink", "udpsrc", NULL }; 
  int i, failed = 0;

  g_debug("%s:%d", G_STRFUNC, __LINE__);

  /* check that all required gst elements are installed */
  for(i = 0; ssc_gst_elements[i] != NULL; i++) {
    GstElementFactory *f = gst_element_factory_find (ssc_gst_elements[i]);
    g_message("Verifying GST element \"%s\" -> %s", 
	      ssc_gst_elements[i],
	      (f ? "OK" : "FAILED"));
    if (f)
      gst_object_unref(f);
    else
      ++failed;
  }

  if (failed) {
    g_warning("Some required gstreamer elements not found on the system, cannot initialize the GStreamer-RTP media subsystem!");
    return FALSE;
  }
  
  return TRUE;
}

static void ssc_media_gst_init (SscMediaGst *object)
{
  SscMediaGst *self = SSC_MEDIA_GST (object);
  const char * const ad_type_getenv = getenv("SOFSIP_AUDIO");
  const char *ad_type = SOFSIP_DEFAULT_AUDIO;
#if __APPLE_CC__
  /* ugly hack, but let's keep maintain the behaviour for OSX users */
  if (strcmp(ad_type, "ALSA") == 0) ad_type = "OSX";
#endif

  if (ad_type_getenv)
    ad_type = ad_type_getenv;

  self->sm_rtp_sockfd = -1;
  /* turn into properties */
  self->sm_ad_input_type = g_strdup(ad_type);
  self->sm_ad_output_type = g_strdup(ad_type);
  self->sm_ad_input_device = NULL;
  self->sm_ad_output_device = NULL;
}

static void ssc_media_gst_finalize (GObject *object)
{
  SscMediaGst *self = SSC_MEDIA_GST (object);
  
  g_debug(G_STRFUNC);
  g_assert(self);
}

static void ssc_media_gst_dispose (GObject *object)
{
  SscMediaGst *self = SSC_MEDIA_GST (object);

  if (!self->dispose_run) {
    self->dispose_run = TRUE;
    
    if (ssc_media_is_initialized(SSC_MEDIA(self)))
      priv_deactivate_gst(SSC_MEDIA(self));

    g_free(self->sm_ad_input_type);
    g_free(self->sm_ad_input_device);
    g_free(self->sm_ad_output_type);
    g_free(self->sm_ad_output_device);
    g_free(self->sm_stun_server);
    g_free(self->sm_stun_domain);
  }
}

static void
ssc_media_gst_set_property (GObject      *object, 
			    guint         prop_id,
			    const GValue *value, 
			    GParamSpec   *pspec)
{
  SscMediaGst *self;
  
  g_return_if_fail (SSC_IS_MEDIA_GST (object));
  self = SSC_MEDIA_GST (object);
  
  switch (prop_id) {
    case PROP_AUDIO_INPUT_TYPE: 
      g_free(self->sm_ad_input_type);
      self->sm_ad_input_type = g_strdup(g_value_get_string (value)); 
      break;
    case PROP_AUDIO_INPUT_DEVICE:
      g_free(self->sm_ad_input_device);
      self->sm_ad_input_device = g_strdup(g_value_get_string (value)); 
      break;
    case PROP_AUDIO_OUTPUT_TYPE:
      g_free(self->sm_ad_output_type);
      self->sm_ad_output_type = g_strdup(g_value_get_string (value)); 
      break;
    case PROP_AUDIO_OUTPUT_DEVICE:
      g_free(self->sm_ad_output_device);
      self->sm_ad_output_device = g_strdup(g_value_get_string (value));
      break;
    case PROP_STUN_SERVER: 
      g_free(self->sm_stun_server);
      self->sm_stun_server = g_strdup(g_value_get_string (value)); 
      break;
    case PROP_STUN_DOMAIN: 
      g_free(self->sm_stun_domain);
      self->sm_stun_domain = g_strdup(g_value_get_string (value)); 
      break;
    default:
      g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
  }
}

static void
ssc_media_gst_get_property (GObject    *object, 
			    guint       prop_id, 
			    GValue     *value,
			    GParamSpec *pspec)
{
  SscMediaGst *self;
  
  g_return_if_fail (SSC_IS_MEDIA_GST (object));
  
  self = SSC_MEDIA_GST (object);
  
  switch (prop_id) {
    case PROP_AUDIO_INPUT_TYPE: g_value_set_string (value, self->sm_ad_input_type); break;
    case PROP_AUDIO_INPUT_DEVICE: g_value_set_string (value, self->sm_ad_input_type); break;
    case PROP_AUDIO_OUTPUT_TYPE: g_value_set_string (value, self->sm_ad_output_type); break;
    case PROP_AUDIO_OUTPUT_DEVICE: g_value_set_string (value, self->sm_ad_output_type); break;
    case PROP_STUN_SERVER: g_value_set_string(value, self->sm_stun_server); break;
    case PROP_STUN_DOMAIN: g_value_set_string(value, self->sm_stun_domain); break;
    default:
      g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
  }
}

static int priv_activate_gst(SscMedia *parent)
{
  SscMediaGst *self = SSC_MEDIA_GST (parent);
  int len = 0, res = 0;
  char *l_sdp_str = NULL;
  sdp_session_t *l_sdp = NULL;
    
  g_debug(G_STRFUNC);

  if (parent->sm_sdp_local == NULL) {
    ssc_media_set_local_to_caps(parent);
  }
  if (parent->sm_sdp_remote == NULL) {
    /* remote SDP not yet known, create a dummy one from 
     * our own SDP */
    ssc_media_set_remote_to_local(parent);
  }

  /* get local port */
  l_sdp = sdp_session(parent->sm_sdp_local);
  if (l_sdp && l_sdp->sdp_media->m_port)
    self->sm_rtp_lport = l_sdp->sdp_media->m_port;

  g_debug(G_STRFUNC);

  /* XXX: if unable to start, report errors via ssc_media_is_active() */

  if (self->sm_depay == NULL) {
    res = priv_setup_rtpelements(self);
  }

  return res;
}

static int priv_refresh_gst(SscMedia *parent)
{
  SscMediaGst *self = SSC_MEDIA_GST (parent);
  int res = 0;

  /* XXX: no RX hot updates supported yet */
  priv_update_tx_elements(self);

  return res;
}

static int priv_deactivate_gst(SscMedia *parent)
{
  SscMediaGst *self = SSC_MEDIA_GST (parent);

  g_assert(ssc_media_is_initialized(parent) == TRUE);

  g_debug(G_STRFUNC);

  if (self->sm_pipeline) {
    /* XXX: freezes with gst-0.8.9, still problems with 0.10.0 */
    gst_element_set_state (self->sm_pipeline, GST_STATE_PAUSED);
    gst_element_set_state (self->sm_pipeline, GST_STATE_NULL);
  }

  parent->sm_state = sm_disabled;

  if (self->sm_netsocket)
    g_object_unref(G_OBJECT (self->sm_netsocket)), self->sm_netsocket = NULL;
  
  if (self->sm_rtp_sockfd != -1)
    close(self->sm_rtp_sockfd), self->sm_rtp_sockfd = -1;
  if (self->sm_rtcp_sockfd != -1)
    close(self->sm_rtcp_sockfd), self->sm_rtp_sockfd = self->sm_rtcp_sockfd = -1;

  if (self->sm_pipeline) {
    /* XXX: gets stuck on gst-0.10.2, must fix, we are leaking memory otherwise */
    gst_object_unref(GST_OBJECT (self->sm_pipeline));

    self->sm_pipeline = NULL;
    self->sm_depay = NULL; /* needed to make activate->deactive work right */
  }

  self->sm_rx_elements = 0;
  self->sm_tx_elements = 0;

  g_assert(ssc_media_is_initialized(parent) != TRUE);
}

static int priv_static_capabilities_gst(SscMedia *parent, char **dest)
{
  SscMediaGst *self = SSC_MEDIA_GST (parent);
  su_home_t *home = parent->sm_home;
  char *caps_sdp_str = NULL;
  GstCaps *pt_caps;
  g_debug(G_STRFUNC);

  self->sm_pt = 0; /* PT=0 => PCMU */

  /* step: initialize the PT<->caps hash table */

  pt_caps = gst_caps_new_simple ("application/x-rtp",
				 "clock-rate", G_TYPE_INT, 8000,
				 "encoding-name", G_TYPE_STRING, "PCMU",
				 NULL);
  
  /* step: describe capabilities in SDP terms */

  /* support only G711/PCMU */
  caps_sdp_str = su_strcat(home, caps_sdp_str, 
			   "v=0\r\n"
			   "m=audio 0 RTP/AVP 0\r\n"
			   "a=rtpmap:0 PCMU/8000\r\n");

  *dest = strdup(caps_sdp_str);
  su_free(home, caps_sdp_str);

  return 0;
}


static int priv_setup_rtpelements(SscMediaGst *self)
{
  GType netsocket_type = FARSIGHT_NETSOCKET_TYPE;
  FarsightNetsocket *netsocket = NULL;
  gboolean cb_sched = FALSE;
  int pri_sockfd, aux_sockfd = -1;
  guint16 l_port = SSC_MEDIA_RTP_PORT_RANGE_START;

  g_debug(G_STRFUNC);

  /* take the local port from local SDP */
  if (self->sm_rtp_lport != 0)
    l_port = self->sm_rtp_lport;

  /* precond: */
  g_assert(self->sm_depay == NULL);

  pri_sockfd = 
      farsight_netsocket_bind_udp_port(AF_INET, 
				       NULL, /* local-if */
				       &l_port, /* use a random port */
				       TRUE, /* scan if l_port was reserved */
				       NULL /* do not request for aux sock */
				       );

  if (pri_sockfd >= 0) {
    self->sm_rtp_sockfd = pri_sockfd;
    self->sm_rtcp_sockfd = aux_sockfd;
    self->sm_rtp_lport = l_port;

    if (self->sm_stun_server || self->sm_stun_domain) {
      self->sm_netsocket = NULL;
      netsocket_type = FARSIGHT_NETSOCKET_STUN_TYPE;
      netsocket = g_object_new (netsocket_type,
				"sockfd", pri_sockfd, 
				"aux-sockfd", aux_sockfd, 
				"server", self->sm_stun_server,
				"domain", self->sm_stun_domain,
				NULL);
      if (netsocket) {
	g_signal_connect (G_OBJECT (netsocket), "ready", 
			  G_CALLBACK (priv_cb_ready), self);
      	self->sm_netsocket = netsocket;

	/* note: the bind will result in a call of sscpriv_cb_ready */
	cb_sched = farsight_netsocket_map(netsocket);
      
	if (cb_sched != TRUE) {
	  g_warning("Problems in initiating connection to STUN server.");
	  g_object_unref(G_OBJECT (self->sm_netsocket)), self->sm_netsocket = NULL;
	}
      }
    }

    if (cb_sched != TRUE) {
      /* STUN not used, emit ready immediately */
      priv_cb_ready(NULL, self);
    }
  }
  else {
    g_error("%s: unable to bind to local sockets.\n", G_STRFUNC);
  }

  return (pri_sockfd >= 0 ? 0 : -1);
}

/**
 * Callback issued when local socket is ready for
 * use.
 */
static void priv_cb_ready(FarsightNetsocket *netsocket, gpointer data)
{
  SscMediaGst *self = SSC_MEDIA_GST(data);
  SscMedia *parent = SSC_MEDIA (self);
  GstElementFactory *factory;
  GstElement *decoder, *depayloader, *audiosink;
  GstElement *src1, *codec, *payload, *udpsrc, *udpsink;
  gsdp_codec_factories_t *factories = gsdp_codec_factories_create("PCMU");

  gint sockfd = -1;

  g_debug(G_STRFUNC);

  if (netsocket != NULL) {
    if (self->sm_rtp_sockfd == -1) 
      g_object_get(G_OBJECT(netsocket), "sockfd", &self->sm_rtp_sockfd);
  }
  
  assert(self->sm_rtp_sockfd > -1);
  
  /* step: create the pipeline */
  if (!self->sm_pipeline) {
    /* step: create a pipeline and assign error callback */
    self->sm_pipeline = gst_pipeline_new ("rtp-pipeline");
    gst_bus_add_watch(gst_pipeline_get_bus(GST_PIPELINE(self->sm_pipeline)), 
		      priv_cb_pipeline_bus, (void*)self);
  }

  /* step: create RX elements */
  if (!self->sm_rx_elements && factories) {
    self->sm_rx_elements = TRUE;

    /* step: create UDP source */
    udpsrc = gst_element_factory_make ("udpsrc", "src");
    assert (udpsrc != NULL);
    self->sm_udpsrc = udpsrc;
    g_object_set(G_OBJECT(self->sm_udpsrc), 
		 "sockfd", self->sm_rtp_sockfd,
		 "port", self->sm_rtp_lport,
		 NULL);

    /* step: create depayloader->decoder->sink chain */
    depayloader = gst_element_factory_create (factories->depayloader, "depayloader");
    assert(depayloader != NULL);
    self->sm_depay = depayloader;
    g_object_set (G_OBJECT(depayloader), "queue_delay", 0, NULL);

    decoder = gst_element_factory_create (factories->decoder, "decoder");
    assert(decoder != NULL);
    self->sm_decoder = decoder;

    audiosink = ssc_media_create_audio_sink(self->sm_ad_output_type);
    assert(audiosink != NULL);
    g_message("Created audio sink of type '%s' for playback.", self->sm_ad_output_type);
    if (!strcmp(self->sm_ad_output_type, "ALSA") && self->sm_ad_output_device)
      g_object_set (G_OBJECT (audiosink), "device", self->sm_ad_output_device, NULL);
    g_object_set (G_OBJECT (audiosink), "latency-time", G_GINT64_CONSTANT (20000), NULL);
    g_object_set (G_OBJECT (audiosink), "buffer-time", G_GINT64_CONSTANT (160000), NULL);
    /* workaround for changed behaviour in gstreamer-0.10.9: */
    g_object_set (G_OBJECT (audiosink), "sync", FALSE, NULL);

    /* step: add elements to the bin and establish links */
    gst_bin_add_many (GST_BIN (self->sm_pipeline), udpsrc, depayloader, decoder, audiosink, NULL);
    gst_element_link_many (udpsrc, depayloader, decoder, audiosink, NULL);
    
  } 
  else {
    g_warning("RX elements already configured, unable update on-the-fly.\n");
  }

  /* step: create TX elements */
  if (!self->sm_tx_elements && factories) {
    self->sm_tx_elements = TRUE;

    /* step: source element */
    src1 = ssc_media_create_audio_src(self->sm_ad_input_type);
    assert(src1 != NULL);
    if (!strcmp(self->sm_ad_input_type, "ALSA") && self->sm_ad_input_device)
      g_object_set (G_OBJECT (src1), "device", self->sm_ad_input_device, NULL);
    g_object_set (G_OBJECT (src1), "latency-time", G_GINT64_CONSTANT (20000), NULL);
    g_object_set (G_OBJECT (src1), "blocksize", 320, NULL); /* 320 octets, 20msec at L16/1 */

    /* step: codec -> rtp-packetizer -> udp */
    codec = gst_element_factory_create (factories->encoder, "codec");
    assert(codec != NULL);
    payload = gst_element_factory_create (factories->payloader, "payload");
    assert(payload != NULL);
    g_object_set (G_OBJECT (payload), "max-ptime", 20 * GST_MSECOND, NULL); /* 20msec */

    /* step: create UDP sink */
    udpsink = gst_element_factory_make ("udpsink", "sink");
    assert (udpsink != NULL);
    self->sm_udpsink = udpsink;

    /* step: add elements to the bin and establish links */
    gst_bin_add_many (GST_BIN (self->sm_pipeline), src1, codec, payload, udpsink, NULL);
    gst_element_link_many (src1, codec, payload, udpsink, NULL);
  }
  else {
    g_warning("TX elements already configured, unable update on-the-fly.\n");
  }

  if (factories)
    gsdp_codec_factories_free(factories);

  priv_update_rx_elements(self);
  priv_update_tx_elements(self);

  g_message ("Starting the pipeline.\n");
  
  gst_element_set_state (self->sm_pipeline, GST_STATE_PLAYING);

  /* note: emit "state-changed" signal from base class */
  ssc_media_signal_state_change (parent, sm_active);
}

static gboolean priv_cb_pipeline_bus (GstBus *bus, GstMessage *message, gpointer data)
{
  SscMediaGst *self = SSC_MEDIA_GST(data);

  switch (GST_MESSAGE_TYPE (message)) {
    case GST_MESSAGE_ERROR: {
      GError *err;
      gchar *debug;

      gst_message_parse_error (message, &err, &debug);
      g_print ("%s: Error: %s\n", G_STRFUNC, err->message);
      g_error_free (err);
      g_free (debug);

      /* XXX: we don't have pointer to the main loop, so let's just
       *      quit the whole thing on error */
      exit(0);
      break;
    }
    case GST_MESSAGE_NEW_CLOCK:
    case GST_MESSAGE_CLOCK_PROVIDE:
      /* normal clock handling events */
      break;

    case GST_MESSAGE_STATE_CHANGED:
      /* state changed */
      break;

    default:
      /* unhandled message */
      g_print ("%s: Unhandled bus message from element %s (%s).\n", 
	       G_STRFUNC, gst_object_get_name(message->src),
	       gst_message_type_get_name(GST_MESSAGE_TYPE(message)));
      break;
  }

  self = NULL;

  /* remove message from the queue */
  return TRUE;
}

/**
 * Updates configuration of RX elements of
 * an already activated session.
 */
static int priv_update_rx_elements(SscMediaGst *self)
{
  SscMedia *parent = SSC_MEDIA (self);
  sdp_session_t *l_sdp;
  int result = 0;

  g_debug(G_STRFUNC);

  if (parent->sm_sdp_local) 
    l_sdp = sdp_session(parent->sm_sdp_local);

  /* step: update the port number in local SDP */
  if (l_sdp) {

    if (self->sm_netsocket) {
      guint c_port = 0;
      gchar *c_addr = NULL;
      g_object_get (G_OBJECT(self->sm_netsocket), 
		    "contactport", &c_port,
		    "contactaddr", &c_addr,
		    NULL);
      
      if (c_addr && c_port) {
	l_sdp->sdp_media->m_port = c_port;

	g_debug("%s: using contact address %s:%u", G_STRFUNC, c_addr, (unsigned int)c_port);
     
	result = sdp_set_contact(parent->sm_sdp_local, l_sdp->sdp_media, sdp_net_in, sdp_addr_ip4, c_addr);
      }
      else {
	g_debug("%s: not modifying local contact address", G_STRFUNC);
      }

      g_free(c_addr);
    }

    if (l_sdp->sdp_media->m_port == 0) {
      /* local media active but SDP port zero, update */
      l_sdp->sdp_media->m_port = self->sm_rtp_lport;
    }

    /* make sure the local ascii-SDP is regenerated */ 
    if (parent->sm_sdp_local_str) 
      g_free(parent->sm_sdp_local_str), parent->sm_sdp_local_str = NULL;
  }

  return result;
}

/**
 * Updates configuration of XX elements of
 * an already activaded session.
 */
static int priv_update_tx_elements(SscMediaGst *self)
{
  SscMedia *parent = SSC_MEDIA (self);
  sdp_session_t *r_sdp = sdp_session(parent->sm_sdp_remote);
  sdp_connection_t *r_c = (!r_sdp) ? NULL : sdp_media_connections(r_sdp->sdp_media);

  g_debug(G_STRFUNC);

  if (r_c && r_sdp) {
    g_return_val_if_fail(self->sm_udpsink != NULL, -1);
    g_message("RTP destination is: %s:%u.", r_c->c_address, r_sdp->sdp_media->m_port);
    g_object_set(G_OBJECT(self->sm_udpsink), 
		 "host", r_c->c_address, 
		 "port", r_sdp->sdp_media->m_port,
		 NULL);
  }
  else 
    g_message("No RTP destination available (r_sdp=%p).", (void*)r_sdp);

  return 0;
}

#endif /* HAVE_GST */
