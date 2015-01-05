/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2007,2008 Nokia Corporation.
 * Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation.
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
 *  - early development
 *
 * Todo:
 *  - see comments marked with 'XXX'
 *
 * Notes:
 *  - none
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_LIBNICE

#include <stdio.h>
#include <string.h>
#include <errno.h>

#include <glib.h>

#include <nice/nice.h>
#include "nice_local.h"
#include "sdp_utils.h"
#include "ssc_media.h"
#include "ssc_media_nice.h"

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
  PROP_STUN_SERVER,
};

static void ssc_media_nice_class_init    (SscMediaNiceClass *klass);
static void ssc_media_nice_init          (SscMediaNice *sscm);
static void ssc_media_nice_dispose       (GObject *object);
static void ssc_media_nice_finalize      (GObject *object);

static void ssc_media_nice_set_property (GObject      *object,
					guint         prop_id,
					const GValue *value,
					GParamSpec   *pspec);
static void ssc_media_nice_get_property (GObject    *object,
					guint       prop_id,
					GValue     *value,
					GParamSpec *pspec);

static int priv_activate_nice(SscMedia *sscm);
static int priv_deactivate_nice(SscMedia *sscm);
static int priv_refresh_nice(SscMedia *sscm);
static int priv_static_capabilities_nice(SscMedia *sscm, char **dst);

static int priv_update_local_sdp(SscMediaNice *self);
static int priv_update_rx_elements(SscMediaNice *self);
static int priv_update_tx_elements(SscMediaNice *self);
static gboolean priv_verify_required_elements(void);

static GObjectClass *parent_class = NULL;
/* static guint ssc_media_nice_signals[SIGNAL_LAST] = { 0 }; */

GType
ssc_media_nice_get_type (void)
{
  static GType type = 0;

  if (type == 0) {
    static const GTypeInfo info = {
      sizeof (SscMediaNiceClass),
      NULL,
      NULL,
      (GClassInitFunc) ssc_media_nice_class_init,
      NULL,
      NULL,
      sizeof (SscMediaNice),
      0,
      (GInstanceInitFunc) ssc_media_nice_init
    };
    
    type = g_type_register_static (SSC_MEDIA_TYPE,
				   "SscMediaNiceType",
				   &info, 0);
  }
  
  return type;
}

static void ssc_media_nice_class_init (SscMediaNiceClass *klass)
{
  GObjectClass *gobject_class;
  SscMediaClass *parent_class = SSC_MEDIA_CLASS(klass);
  
  g_debug("%s:%d", __func__, __LINE__);
  
  gobject_class = (GObjectClass *) klass;
  gobject_class->dispose = ssc_media_nice_dispose;
  gobject_class->finalize = ssc_media_nice_finalize;
  gobject_class->set_property = ssc_media_nice_set_property;
  gobject_class->get_property = ssc_media_nice_get_property;
  
  /* assign default methods */
  parent_class->activate = priv_activate_nice;
  parent_class->deactivate = priv_deactivate_nice;
  parent_class->refresh = priv_refresh_nice;
  parent_class->static_capabilities = priv_static_capabilities_nice;

  /* property: STUN server */
  g_object_class_install_property (G_OBJECT_CLASS (klass), PROP_STUN_SERVER,
				   g_param_spec_string ("stun-server", "STUN server address",
							"STUN server IP address",
							NULL, G_PARAM_READWRITE));

}

static gboolean dummy_sender_tick (gpointer pointer)
{
  SscMediaNice *self = SSC_MEDIA_NICE (pointer);
  SscMedia *parent = SSC_MEDIA (self);
  
  if (parent->sm_state == sm_active ||
      parent->sm_state == sm_local_ready) {
    /* note: stop sending test packets when we received first
     *       test packet back */
    if (self->nice_test_packets_sent == 0) {
      const char rtp_buf[] = { 
	0x80,       /* RTP v2 header, no padding, extensions nor CSRCs */
	0x7F,       /* payload 127, used for NICE testing */
	0x00, 0x00, /* sequence number */
	0x00, 0x00, 0x00, 0x00, /* timestamp */
	0x00, 0x00, 0x00, 0x00, /* ssrc */
      };
      g_debug ("Sending a NICE test packet (both to RTP/RTCP)...");
      nice_agent_send (self->agent,
		       self->stream_id,
		       NICE_COMPONENT_TYPE_RTP,
		       sizeof (rtp_buf),
		       rtp_buf);
      ++self->nice_test_packets_sent;
      nice_agent_send (self->agent,
		       self->stream_id,
		       NICE_COMPONENT_TYPE_RTCP,
		       sizeof (rtp_buf),
		       rtp_buf);
      ++self->nice_test_packets_sent;

      return TRUE;
    }
  }

  g_debug ("Stopping RTP transmission timer..");
  self->dummy_timer_id = 0;
  return FALSE;
}

static void cb_nice_recv (NiceAgent *agent, guint stream_id, guint component_id, guint len, gchar *buf, gpointer user_data)
{
  SscMediaNice *self = SSC_MEDIA_NICE (user_data);
  SscMedia *parent = SSC_MEDIA (self);

  g_debug ("%s: stream_id=%u, component_id=%u, len=%u, self=%p", 
	   __func__, stream_id, component_id, len, self);

  if (self->stream_id != stream_id)
    return;

  /* check RTP version */
  if (len > 11 &&
      (buf[0] & 0xc0) == 0x80)
    ++self->rtp_packets_received;

  /* step: check whether this is NICE check packet */
  if (len == 12 &&
      buf[1] == 0x7F) {
    g_debug ("NICE media test packet received.");
    ++self->nice_test_packets_received;
    if (self->nice_test_packets_received >= 2)
      ssc_media_signal_state_change (parent, sm_active);
  }
  /* step: otherwise loop back the packet (for non-test clients) */
  else {
    ++self->looped_rtp_packets;
    
    /* step: pick our own SSRC */
    if (self->ssrc == 0 &&
	len > 11 &&
	(buf[0] & 0xc0) == 0x80) {
      guint32 tmp;
      g_assert (sizeof(tmp) == 4);
      memcpy (&tmp, buf + 8, sizeof(tmp));
      self->ssrc = ++tmp; /* ignore endianess */
      g_debug ("Picked an SSRC for looped back packets: %u (RX %u).", self->ssrc, tmp);
    }

    /* step: replace the SSRC (bits 65:96) of looped back packets */
    if (len > 11) {
      memcpy (buf + 8, &self->ssrc, 4);
    }

    nice_agent_send (self->agent,
		     stream_id,
		     component_id, 
		     len,
		     buf);
  }
}

static void priv_cb_candidate_gathering_done(NiceAgent *agent, guint stream_id, gpointer data)
{
  SscMediaNice *self = SSC_MEDIA_NICE (data);
  SscMedia *parent = SSC_MEDIA (self);

  g_debug (__func__);

  self->gathering_done = TRUE;

  if (self->stream_id > 0) {
    priv_update_local_sdp(self);
    ssc_media_signal_state_change (parent, sm_local_ready);
  }
}

static void priv_cb_component_state_changed(NiceAgent *agent, guint stream_id, guint component_id, guint state, gpointer data)
{
  SscMediaNice *self = SSC_MEDIA_NICE (data);
  SscMedia *parent = SSC_MEDIA (self);
  gboolean remove_timer = FALSE;

  g_debug ("%s: stream_id=%u, component_id=%u, state=%d, self=%p", 
	   __func__, stream_id, component_id, state, self);

  if (component_id == NICE_COMPONENT_TYPE_RTP)
    self->rtp_state = state;
  else if (component_id == NICE_COMPONENT_TYPE_RTCP)
    self->rtcp_state = state;

  /* note: once state changes to CONNECTED, start a timer to send packets 
   *  - maybe send a one custom packet at start
   *    and then start echoing back (filtering out packages sent
   *    by ourselves to avoid infinite loops...? */

  if (self->stream_id == stream_id) {
    if (self->rtp_state == NICE_COMPONENT_STATE_READY && 
	self->rtcp_state == NICE_COMPONENT_STATE_READY) {
      if (self->dummy_timer_id == 0) {
	g_debug ("Starting RTP transmission timer.");
	self->dummy_timer_id = 
	  g_timeout_add (20, dummy_sender_tick, self);
      }
    }
    else if (self->rtp_state == NICE_COMPONENT_STATE_DISCONNECTED &&
	     self->rtcp_state == NICE_COMPONENT_STATE_DISCONNECTED) {
      g_debug ("Component state to DISCONNECTED.");
      remove_timer = TRUE;
    }
    else if (self->rtp_state == NICE_COMPONENT_STATE_FAILED ||
	     self->rtcp_state == NICE_COMPONENT_STATE_FAILED) {
      g_debug ("Component state to FAILED.");
      remove_timer = TRUE;
      ++self->nice_test_failed;
      ssc_media_signal_state_change (parent, sm_error);
    }
  }

  if (remove_timer &&
      self->dummy_timer_id > 0) {
    g_debug ("Cancelling RTP transmission timer.");
    g_source_remove (self->dummy_timer_id),
      self->dummy_timer_id = 0;
  }
}


static void ssc_media_nice_init (SscMediaNice *object)
{
  SscMediaNice *self = SSC_MEDIA_NICE (object);
  GSList *interfaces, *i;

  g_debug(__func__);

  self->agent = nice_agent_new(g_main_context_default(), NICE_COMPATIBILITY_DRAFT19);
  self->stream_id = 0;

  g_signal_connect (G_OBJECT (self->agent), "candidate-gathering-done", 
		    G_CALLBACK (priv_cb_candidate_gathering_done), self);
  g_signal_connect (G_OBJECT (self->agent), "component-state-changed", 
		    G_CALLBACK (priv_cb_component_state_changed), self);

  interfaces = nice_list_local_interfaces();
  for (i = interfaces; i; i = i->next) {
    NiceInterface *iface = i->data;
    NiceAddress *addr = NULL;
    NiceAddress nulladdr = { 0 };

#ifdef DEBUG
    {
      gchar ip[NICE_ADDRESS_STRING_LEN];
      
      nice_address_to_string (iface->addr, ip);
      g_debug ("s: %s\n", iface->name, ip);
    }
#endif

    if (iface->addr.s.addr.sa_family == AF_INET &&
	strcmp(iface->name, "lo") != 0) {
      addr = nice_address_dup(&iface->addr);
      nice_agent_add_local_address (self->agent, addr);
    }

    nice_interface_free (iface);
  }
}

static void ssc_media_nice_finalize (GObject *object)
{
  SscMediaNice *self = SSC_MEDIA_NICE (object);
  
  g_debug(__func__);
  g_assert(self);
}

static void ssc_media_nice_dispose (GObject *object)
{
  SscMediaNice *self = SSC_MEDIA_NICE (object);

  g_debug(__func__);

  if (!self->dispose_run) {
    self->dispose_run = TRUE;

    if (ssc_media_state (SSC_MEDIA(self)) != sm_disabled) 
      priv_deactivate_nice(SSC_MEDIA(self));

    if (self->dummy_timer_id > 0)
      g_source_remove (self->dummy_timer_id),
	self->dummy_timer_id = 0;
    
    g_free(self->local_rtp_foundation);
    g_free(self->local_rtcp_foundation);
    g_free(self->sm_stun_server);

    g_object_unref(self->agent);
  }
}

static void
ssc_media_nice_set_property (GObject      *object, 
			    guint         prop_id,
			    const GValue *value, 
			    GParamSpec   *pspec)
{
  SscMediaNice *self;
  
  g_return_if_fail (SSC_IS_MEDIA_NICE (object));
  self = SSC_MEDIA_NICE (object);
  
  switch (prop_id) {
    case PROP_STUN_SERVER: 
      g_free(self->sm_stun_server);
      self->sm_stun_server = g_strdup(g_value_get_string (value)); 
      break;
    default:
      g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
  }
}

static void
ssc_media_nice_get_property (GObject    *object, 
			    guint       prop_id, 
			    GValue     *value,
			    GParamSpec *pspec)
{
  SscMediaNice *self;
  
  g_return_if_fail (SSC_IS_MEDIA_NICE (object));
  
  self = SSC_MEDIA_NICE (object);
  
  switch (prop_id) {
    case PROP_STUN_SERVER: g_value_set_string(value, self->sm_stun_server); break;
    default:
      g_debug("Unknown object property %s:%u.", G_OBJECT_TYPE_NAME(object), prop_id);
  }
}

static int priv_activate_nice(SscMedia *parent)
{
  SscMediaNice *self = SSC_MEDIA_NICE (parent);
    
  g_debug(__func__);

  /* note: only one stream at a time */
  if (self->stream_id > 0)
    return -1;

  self->rtp_packets_received = 0;
  self->nice_test_packets_received = 0;
  self->nice_test_packets_sent = 0;
  self->nice_test_failed = 0;
  self->looped_rtp_packets = 0;

  if (self->sm_stun_server) {
    g_debug ("SSC-NICE: using STUN server %s.", self->sm_stun_server);
    g_object_set (G_OBJECT (self->agent), 
		  "stun-server", self->sm_stun_server,
		  NULL);
  }

  /* making initial offer */
  if (parent->sm_sdp_remote == NULL)
    g_object_set (G_OBJECT (self->agent), 
		  "controlling-mode", TRUE, NULL);
  else
    g_object_set (G_OBJECT (self->agent), 
		  "controlling-mode", FALSE, NULL);

  self->gathering_done = FALSE;
  /* note: add a stream with RTP/RTCP components */
  self->stream_id = nice_agent_add_stream (self->agent, 2);
  self->ssrc = 0;

  nice_agent_gather_candidates (self->agent, self->stream_id);
  
  nice_agent_attach_recv (self->agent, self->stream_id, NICE_COMPONENT_TYPE_RTP,
      g_main_context_default(), cb_nice_recv,
      self);
  nice_agent_attach_recv (self->agent, self->stream_id, NICE_COMPONENT_TYPE_RTCP,
      g_main_context_default(), cb_nice_recv,
      self);

  if (self->stream_id > 0) {
    priv_update_local_sdp(self);

    if (self->gathering_done)
      ssc_media_signal_state_change (parent, sm_local_ready);

    return 0;
  }

  return -1;
}

/* XXX: add to NICE library side */
static const char *candidate_type_strings[5] = {
  "host",   /* NICE_CANDIDATE_TYPE_HOST */
  "srflx",  /* NICE_CANDIDATE_TYPE_SERVER_REFLEXIVE */
  "prflx",  /* NICE_CANDIDATE_TYPE_PEER_REFLEXIVE */
  "relay",  /* NICE_CANDIDATE_TYPE_RELAYED */
  NULL
};

/* XXX: add to NICE library side */
static const char *candidate_transport_strings[2] = {
  "UDP",   /* NICE_CANDIDATE_TRANSPORT_UDP */
  NULL
};

/** Returns NiceCandidateTransport enum. */
static int priv_parse_nice_transport (const char* input)
{
  if (strcmp ("UDP", input) == 0)
    return NICE_CANDIDATE_TRANSPORT_UDP;
}

/** Returns NiceCandidateType enum. */
static int priv_parse_nice_type (const char* input)
{
  if (strcmp ("host", input) == 0)
    return NICE_CANDIDATE_TYPE_HOST;

  if (strcmp ("srflx", input) == 0)
    return NICE_CANDIDATE_TYPE_SERVER_REFLEXIVE;

  if (strcmp ("prflx", input) == 0)
    return NICE_CANDIDATE_TYPE_PEER_REFLEXIVE;

  if (strcmp ("relay", input) == 0)
    return NICE_CANDIDATE_TYPE_RELAYED;

}

/**
 * Fetches the default address, and ports for RTP and RTCP 
 * from the available local ICE candidates.
 */
static void priv_pick_default_candidate(SscMediaNice *self, guint16 *mline_port, gchar **cline_address, guint16 *rtcp_port)
{
  GSList *local_cands = NULL, *i;

  local_cands = nice_agent_get_local_candidates(self->agent, self->stream_id, NICE_COMPONENT_TYPE_RTP);
  for (i = local_cands; i; i = i->next) {
    NiceCandidate *cand = i->data;
    gchar cand_addr_str[NICE_ADDRESS_STRING_LEN];

    nice_address_to_string (&cand->addr, cand_addr_str);

    if (mline_port && *mline_port == 0)
      *mline_port = nice_address_get_port (&cand->addr);

    if (cline_address && *cline_address == NULL)
      *cline_address = g_strdup(cand_addr_str);
  }

  local_cands = nice_agent_get_local_candidates(self->agent, self->stream_id, NICE_COMPONENT_TYPE_RTCP);
  for (i = local_cands; i; i = i->next) {
    NiceCandidate *cand = i->data;

    if (rtcp_port && *rtcp_port == 0)
      *rtcp_port = nice_address_get_port (&cand->addr);
  }
}

static gchar *priv_add_candidate_to_sdp (SscMediaNice *self, guint c_id, gchar *cands_str)
{
  GSList *local_cands = NULL, *i;
  gchar *result = cands_str;

  local_cands = nice_agent_get_local_candidates(self->agent, self->stream_id, c_id);
  for (i = local_cands; i; i = i->next) {
    NiceCandidate *cand = i->data;
    gchar cand_addr_str[NICE_ADDRESS_STRING_LEN];

    nice_address_to_string (&cand->addr, cand_addr_str);

    gchar *tmp = g_strdup_printf("a=candidate:%s %u %s %u %s %u typ %s\r\n", 
				 cand->foundation, /* note: foundation */
				 c_id,
				 "UDP",
				 cand->priority,
				 cand_addr_str,
				 nice_address_get_port (&cand->addr),
				 candidate_type_strings[cand->type]);

    if (c_id == NICE_COMPONENT_TYPE_RTP &&
	!self->local_rtp_foundation)
      self->local_rtp_foundation = g_strdup (cand->foundation);

    if (c_id == NICE_COMPONENT_TYPE_RTCP &&
	!self->local_rtcp_foundation)
      self->local_rtcp_foundation = g_strdup (cand->foundation);

    if (result) {
      gchar *tmp2 = g_strconcat(result, tmp, NULL);
      g_free (result);
      g_free (tmp);
      result = tmp2;
    }
    else 
      result = tmp;
  }

  g_slist_free (local_cands);

  return result;
}

/**
 * Refreshes the local SDP based on Farsight stream, and current
 * object, state.
 */
static int priv_update_local_sdp(SscMediaNice *self)
{
  gchar *whole_str;
  gchar *aline_str, *cline_str, *cline_addr = NULL, *mline_str, *cands_str = NULL;
  gchar *ufrag = NULL, *password = NULL;
  GSList *local_cands = NULL, *i;
  int result = -1;
  guint16 mline_port = 0, rtcp_port = 0;

  /* note: following implemantation limitations
   * - no multi-stream support
   * - no IPv6 support */

  g_assert (self->stream_id > 0);

  cands_str = priv_add_candidate_to_sdp(self, NICE_COMPONENT_TYPE_RTP, cands_str);
  cands_str = priv_add_candidate_to_sdp(self, NICE_COMPONENT_TYPE_RTCP, cands_str);
  priv_pick_default_candidate(self, &mline_port, &cline_addr, &rtcp_port);

  nice_agent_get_local_credentials(self->agent, self->stream_id, &ufrag, &password);

  mline_str = g_strdup_printf("m=audio %u RTP/AVP 0", mline_port);
  cline_str = g_strdup_printf("c=IN IP4 %s", cline_addr);
  aline_str = g_strdup_printf("a=rtcp:%u", rtcp_port);

  whole_str =
    g_strdup_printf(
      "v=0\r\n%s\r\n%s\r\na=rtpmap:0 PCMU/8000\r\n%sa=ice-pwd:%s\r\na=ice-ufrag:%s\r\n%s\r\n",
      mline_str,
      cline_str,
      cands_str, /* contains CRLFs */
      password,
      ufrag,
      aline_str);

  g_free(password);		    
  g_free(ufrag);

  printf("Regenerated local SDP:{\n%s}\n", whole_str);

  g_object_set(G_OBJECT(self), 
	       "localsdp", whole_str, NULL);

  g_free(cands_str);
  g_free(mline_str);
  g_free(cline_str);
  g_free(cline_addr);
  g_free(aline_str);
  g_free(whole_str);
}

static void priv_free_remote_cands_list (GSList *cands)
{
  GSList *i;

  for (i = cands; i; i = i->next) {
    NiceCandidate *cand = i->data;
    /* note: NiceAddresses are allocated from stack */
    nice_candidate_free(cand);
  }
  
  g_slist_free (cands);
}

/**
 * Parses information about ICE candidates from the SDP
 * sent by remote party.
 */
void priv_set_remote_sdp_candidates(SscMediaNice *self)
{
  SscMedia *parent = SSC_MEDIA (self);
  const char *result = NULL, *ufrag = NULL, *password = NULL;
  GSList *rtp_cands = NULL, *rtcp_cands = NULL, *i;
  char ice_mode = 1;

  /* note: extract general information from remote SDP */
  sdp_session_t *r_sdp = sdp_session(parent->sm_sdp_remote);
  unsigned port = (r_sdp && r_sdp->sdp_media) ? r_sdp->sdp_media->m_port : 0;
  sdp_attribute_t *attr, *attrs = (r_sdp && r_sdp->sdp_media) ? r_sdp->sdp_media->m_attributes : NULL;
  sdp_connection_t *r_c = NULL;

  g_debug(__func__);

  if (r_sdp)
    if (r_sdp->sdp_connection)
      r_c = r_sdp->sdp_connection;
    else if (r_sdp->sdp_media)
      r_c = sdp_media_connections(r_sdp->sdp_media);

  /* do not continue if remote SDP not available */
  if (!r_c || port == 0)
    return;

  /* note: do not parse if remote port is zero */
  for(attr = attrs; attr; attr = attr->a_next) {

    /* step: check for ICE candidate attribute */
    if (strcmp(attr->a_name, "candidate") == 0) {
      char *candidate_id = NULL;
      unsigned long int component_id, c_port;
      char *transport = NULL;
      guint32 prio;
      char *c_address = NULL, *type = NULL;
      int scanres = 0;
      NiceAddress *addr = NULL;

      /* note: using the GNU extension 'a', do not mix with the C99
         attribute */
      scanres = sscanf(attr->a_value, "%as %lu %as %lu %as %lu typ %as",
		       &candidate_id,
		       &component_id,
		       &transport,
		       &prio,
		       &c_address,
		       &c_port,
		       &type);

      g_debug ("sscanf returned %d (input='%s', parsed component/candidate %u/%s).", scanres, attr->a_value, component_id, candidate_id);

      /* check that all 7 tokens were parsed correctly, fail otherwise */
      if (scanres == 7 &&
	  strcmp ("UDP", transport) == 0) {

	NiceCandidate *cand = nice_candidate_new(priv_parse_nice_type (type));
    
	strncpy(cand->foundation, candidate_id, NICE_CANDIDATE_MAX_FOUNDATION);
	cand->component_id = component_id;
	cand->transport = priv_parse_nice_transport (transport);
	free (transport);
	cand->priority = prio;
	g_assert (nice_address_set_from_string (&cand->addr, c_address) == TRUE);
	nice_address_set_port (&cand->addr, c_port);
	free (type);

	if (component_id == NICE_COMPONENT_TYPE_RTP)
	  rtp_cands = g_slist_append (rtp_cands, cand);
	else if (component_id == NICE_COMPONENT_TYPE_RTCP)
	  rtcp_cands = g_slist_append (rtcp_cands, cand);
	else
	  g_debug ("Unknown ICE component types in remote SDP! Ignoring...");
      }
    }
    /* step: check for ICE credentials */
    else if (strcmp(attr->a_name, "ice-pwd") == 0) {
      password = attr->a_value;
    }
    else if (strcmp(attr->a_name, "ice-ufrag") == 0) {
      ufrag = attr->a_value;
    }
  }

  if (ufrag && password) {
    g_debug ("Found ice-ufrag:%s.", ufrag);
    g_debug ("Found ice-pwd:%s.", password);
    nice_agent_set_remote_credentials (self->agent,
				       self->stream_id,
				       ufrag,
				       password);
  }

  if (g_slist_length(rtp_cands) == 0) {
    NiceCandidate *cand = g_slice_new0 (NiceCandidate);

    g_debug ("Remote does not support ICE, falling back to non-ICE mode.");

    ice_mode = 0;

    strcpy(cand->foundation, "1");
    cand->component_id = NICE_COMPONENT_TYPE_RTP;
    cand->transport = NICE_CANDIDATE_TRANSPORT_UDP;
    cand->priority = 1;
    if (r_c)
      g_assert (nice_address_set_from_string (&cand->addr, r_c->c_address) == TRUE);
    nice_address_set_port (&cand->addr, port),
    rtp_cands = g_slist_append (rtp_cands, cand);
  }
      
  nice_agent_set_remote_candidates (self->agent,
				    self->stream_id,
				    NICE_COMPONENT_TYPE_RTP,
				    rtp_cands);
  priv_free_remote_cands_list (rtp_cands);

  if (g_slist_length(rtcp_cands) > 0) {
    nice_agent_set_remote_candidates (self->agent,
				      self->stream_id,
				      NICE_COMPONENT_TYPE_RTCP,
				      rtcp_cands);
    priv_free_remote_cands_list (rtcp_cands);
  }

  if (!ice_mode) {
    nice_agent_set_selected_pair (self->agent, self->stream_id, NICE_COMPONENT_TYPE_RTP, self->local_rtp_foundation, "1");
    nice_agent_set_selected_pair (self->agent, self->stream_id, NICE_COMPONENT_TYPE_RTCP, self->local_rtcp_foundation, "1");
  }
}

/**
 * Called when either local or remote SDP is modified
 * by the signaling events.
 */
static int priv_refresh_nice(SscMedia *parent)
{
  SscMediaNice *self = SSC_MEDIA_NICE (parent);
  priv_set_remote_sdp_candidates (self);
}

static int priv_deactivate_nice(SscMedia *parent)
{
  SscMediaNice *self = SSC_MEDIA_NICE (parent);

  g_assert (ssc_media_state(SSC_MEDIA(self)) != sm_disabled);

  g_debug(__func__);

  g_debug ("End of session summary:");
  g_debug ("\tRTP packets received: %u", self->rtp_packets_received);
  g_debug ("\tNICE test packets received: %u", self->nice_test_packets_received);
  g_debug ("\tLooped back RTP packets: %u", self->looped_rtp_packets);
  g_debug ("\tErrors in establishing connectivity: %u", self->nice_test_failed);

  /* clear remote SDP */
  if (parent->sm_sdp_remote)
    sdp_parser_free(parent->sm_sdp_remote),
      parent->sm_sdp_remote = NULL;

  g_free(self->local_rtp_foundation),
    self->local_rtp_foundation = NULL;
  g_free(self->local_rtcp_foundation),
    self->local_rtcp_foundation = NULL;

  nice_agent_remove_stream (self->agent, self->stream_id);
  self->stream_id = 0;

  ssc_media_signal_state_change (parent, sm_disabled);

  g_assert (ssc_media_state(SSC_MEDIA(self)) == sm_disabled);
}

static int priv_static_capabilities_nice(SscMedia *parent, char **dest)
{
  SscMediaNice *self = SSC_MEDIA_NICE (parent);
  su_home_t *home = parent->sm_home;
  char *caps_sdp_str = NULL;

  /* XXX: not really 100% accurate, we most likely have support for
   *      more codecs */
  caps_sdp_str = su_strcat(home, caps_sdp_str, 
			   "v=0\r\n"
			   "m=audio 0 RTP/AVP 0\r\n"
			   "a=rtpmap:0 PCMU/8000\r\n");

  *dest = strdup(caps_sdp_str);
  su_free(home, caps_sdp_str);

  return 0;
}

#endif /* HAVE_LIBNICE */
