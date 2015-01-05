/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005,2006,2007,2009 Nokia Corporation.
 * Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
 *
 * This library is free software; you can redistribute it and/or
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

/**@file ssc_sip.c Interface towards libsofia-sip-ua.
 * 
 * @author Kai Vehmanen <kai.vehmanen@nokia.com>
 * @author Pekka Pessi <pekka.pessi@nokia.com>
 */

/*
 * Status:
 *  - works
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

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>

/* note: glib is still a mandatory library - this is just to mark places
 *       of glib/gobject use in code */
#if HAVE_GLIB
#include "ssc_media.h"
#define HAVE_MEDIA_IMPL 1
#else
#define HAVE_MEDIA_IMPL 0
#endif

#if HAVE_GST
#include <gst/gst.h>
#include "ssc_media_gst.h"
#endif
#if HAVE_LIBNICE
#include "ssc_media_nice.h"
#endif

#include <sofia-sip/stun_tag.h>
#include <sofia-sip/su_source.h>

#include "ssc_sip.h"
#include "ssc_oper.h"

/* Function prototypes
 * ------------------- */

void ssc_i_fork(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip, tagi_t tags[]);
void ssc_i_invite(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op, 
		  sip_t const *sip, tagi_t tags[]);
void ssc_i_state(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		 nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip, tagi_t tags[]);
void ssc_i_active(nua_t *nua, ssc_t *ssc,  nua_handle_t *nh, ssc_oper_t *op, 
		  sip_t const *sip, tagi_t tags[]);
void ssc_i_prack(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op, 
		 sip_t const *sip, tagi_t tags[]);
void ssc_i_bye(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op,
	       sip_t const *sip, tagi_t tags[]);
void ssc_i_cancel(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op, 
		  sip_t const *sip, tagi_t tags[]);
void ssc_r_message(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip, tagi_t tags[]);
void ssc_i_message(nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip, tagi_t tags[]);
void ssc_i_info(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op, 
		sip_t const *sip, tagi_t tags[]);
void ssc_i_refer(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op,
		 sip_t const *sip, tagi_t tags[]);
void ssc_i_notify(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op,
		  sip_t const *sip, tagi_t tags[]);
void ssc_i_error(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op, int status, 
		 char const *phrase, tagi_t tags[]);

void ssc_r_info(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		tagi_t tags[]);
void ssc_r_bye(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
	       nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
	       tagi_t tags[]);
void ssc_r_register(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		    tagi_t tags[]);
void ssc_r_unregister(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		      nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		      tagi_t tags[]);
void ssc_r_publish(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[]);
void ssc_r_invite(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		  tagi_t tags[]);
void ssc_r_media_event(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		       nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		       tagi_t tags[]);
void ssc_r_shutdown(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		    tagi_t tags[]);
void ssc_r_get_params(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		      nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		      tagi_t tags[]);
void ssc_r_refer(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[]);
void ssc_r_subscribe(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		     nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		     tagi_t tags[]);
void ssc_r_unsubscribe(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		       nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		       tagi_t tags[]);
void ssc_r_notify(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[]);
void ssc_i_options(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[]);
void ssc_r_options(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[]);
void ssc_r_media_describe(int status, char const *phrase, nua_t *nua, ssc_t *ssc,
			  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
			  tagi_t tags[]);

static void priv_callback(nua_event_t event, int status, char const *phrase,
			  nua_t *nua, ssc_t *ssc, nua_handle_t *nh, 
			  ssc_oper_t *op, sip_t const *sip, tagi_t tags[]);

static char *priv_parse_domain(su_home_t *home, const char *sip_aor);
static void priv_media_state_cb(void* context, guint state, gpointer data);
static SscMedia *priv_create_ssc_media(ssc_t *self, const ssc_conf_t *conf);
static void priv_destroy_oper_with_disconnect (ssc_t *self, ssc_oper_t *oper);

/* Function definitions
 * -------------------- */

ssc_t *ssc_create(su_home_t *home, su_root_t *root, const ssc_conf_t *conf)
{
  ssc_t *ssc;
  char *caps_str;
  char *userdomain = NULL;
  const char *contact;

  ssc = su_zalloc(home, sizeof(*ssc));
  if (!ssc)
    return ssc;

  ssc->ssc_name = "UA";
  ssc->ssc_home = home;
  ssc->ssc_root = root;

  /* step: create media subsystem instance */
  ssc->ssc_media = priv_create_ssc_media(ssc, conf);

#if HAVE_MEDIA_IMPL
  g_assert(ssc->ssc_media);
  /* step: query capabilities of the media subsystem */
  ssc_media_static_capabilities(ssc->ssc_media, &caps_str);
#else
    printf("%s: WARNING, no media subsystem available, disabling media features\n", ssc->ssc_name);
#endif /* HAVE_MEDIA_IMPL */

  /* step: find out the home domain of the account */
  if (conf->ssc_aor)
    userdomain = priv_parse_domain(home, conf->ssc_aor);

  ssc->ssc_address = su_strdup(home, conf->ssc_aor);
  ssc->ssc_autoanswer = conf->ssc_autoanswer;

  /* note: by default bind to a random port on all interfaces */
  if (conf->ssc_contact)
    contact = conf->ssc_contact;
  else
    contact = "sip:*:*"; 
  
  /* step: launch the SIP stack */
  ssc->ssc_nua = nua_create(root, 
			    priv_callback, ssc,
			    TAG_IF(conf->ssc_aor,
				   SIPTAG_FROM_STR(conf->ssc_aor)),
			    TAG_IF(conf->ssc_proxy,
				   NUTAG_PROXY(conf->ssc_proxy)),
			    TAG_IF(conf->ssc_registrar,
				   NUTAG_REGISTRAR(conf->ssc_registrar)),
			    TAG_IF(conf->ssc_contact, 
				   NUTAG_URL(conf->ssc_contact)),
			    TAG_IF(conf->ssc_media_addr,
				   NUTAG_MEDIA_ADDRESS(conf->ssc_media_addr)),

			    /* note: use of STUN for signaling disabled */
			    /* TAG_IF(conf->ssc_stun_server, STUNTAG_SERVER(conf->ssc_stun_server)), */
			    /* TAG_IF(userdomain, STUNTAG_DOMAIN(userdomain)), */

			    /* Used in OPTIONS */
			    TAG_IF(caps_str, 
				   SOATAG_USER_SDP_STR(caps_str)),
			    SOATAG_AF(SOA_AF_IP4_IP6),
			    TAG_NULL());

  /* step: free the static caps */
  free(caps_str);
  
  if (conf->ssc_register)
    ssc_register(ssc, NULL);

  if (ssc->ssc_nua) {
    nua_set_params(ssc->ssc_nua,
		   NUTAG_ENABLEMESSAGE(1),
		   NUTAG_ENABLEINVITE(1),
		   NUTAG_AUTOALERT(1),
		   NUTAG_SESSION_TIMER(0),
		   NUTAG_AUTOANSWER(0),
		   TAG_IF(conf->ssc_certdir,
			  NUTAG_CERTIFICATE_DIR(conf->ssc_certdir)),
		   TAG_NULL());
    nua_get_params(ssc->ssc_nua, TAG_ANY(), TAG_NULL());
  }
  else {
    ssc_destroy(ssc);
    ssc = NULL;
  }

  su_free(home, userdomain);
    
  return ssc;
}

/** 
 * Disconnects GObject signal 'state-changed' and destroys
 * operator handle.
 */
static void priv_destroy_oper_with_disconnect (ssc_t *self, ssc_oper_t *op)
{
  g_signal_handlers_disconnect_matched (G_OBJECT (self->ssc_media),
					(GSignalMatchType) (G_SIGNAL_MATCH_FUNC | G_SIGNAL_MATCH_DATA),
					0, 0, NULL, G_CALLBACK (priv_media_state_cb), op);
  ssc_oper_destroy(self, op);
}

static SscMedia *priv_create_ssc_media(ssc_t *self, const ssc_conf_t *conf)
{
  const char *impl = conf->ssc_media_impl;
  SscMedia *res_impl = NULL;
  char *userdomain = NULL;

  /* step: find out the home domain of the account */
  if (conf->ssc_aor)
    userdomain = priv_parse_domain(self->ssc_home, conf->ssc_aor);

  if (!impl) {
    /* set the default impl to select if available */
    impl = "gstreamer";
  }

#if HAVE_MEDIA_IMPL == 0
  res_impl = NULL;
  impl = "none";
#else /* HAVE_MEDIA_IMPL */
# if HAVE_LIBNICE
  if (!res_impl && strstr(impl, "nice")) {
    res_impl = g_object_new (SSC_MEDIA_NICE_TYPE, NULL);
    if (res_impl) {
      g_object_set(G_OBJECT(res_impl), "stun-server", conf->ssc_stun_server, NULL);
    }
  }
# endif
# if HAVE_GST
  if (!res_impl && strstr(impl, "gstreamer")) {
    res_impl = g_object_new (SSC_MEDIA_GST_TYPE, NULL);
    if (res_impl) {
      g_object_set(G_OBJECT(res_impl), "stun-server", conf->ssc_stun_server, NULL);
      g_object_set(G_OBJECT(res_impl), "stun-domain", userdomain, NULL);
    }
  }
# endif /* HAVE_GST */
  if (!res_impl) {
    /* select dummy if others not available */
    res_impl = g_object_new (SSC_MEDIA_TYPE, NULL);
    impl = "dummy";
  }
#endif /* HAVE_MEDIA_IMPL */

  su_free(self->ssc_home, userdomain);

  g_message("Selecting media implementation: %s", impl);

  return res_impl;
}

void ssc_destroy(ssc_t *self)
{
  su_home_t *home = self->ssc_home;
  
  if (self->ssc_media)
    g_object_unref(self->ssc_media), self->ssc_media = NULL;
  if (self->ssc_address)
    su_free(home, self->ssc_address);

  su_free(home, self);
}

static ssc_auth_item_t *priv_store_pending_auth(su_home_t *home, const char *scheme, msg_param_t const *au_params)
{
  const char *realm = msg_params_find(au_params, "realm=");
  ssc_auth_item_t *authitem = su_zalloc(home, sizeof(*authitem));

  if (authitem) {
    authitem->ssc_scheme = su_strdup(home, scheme);
    if (realm)
      authitem->ssc_realm = su_strdup(home, realm);
  }
  
  return authitem;
}

inline void priv_attach_op_and_username(ssc_t *self, ssc_auth_item_t *authitem, sip_from_t const *sipfrom, su_home_t *home, ssc_oper_t *op)
{
  authitem->ssc_op = op;

  if (sipfrom && sipfrom->a_url)
    authitem->ssc_username = su_strdup(home, sipfrom->a_url->url_user);

  /* XXX: should check for already existing entries for the realm */
  nua_handle_ref(op->op_handle);

  self->ssc_auth_pend = g_list_append(self->ssc_auth_pend, authitem);
}

/**
 * Stores a pending authenticated challenge for operation 'op' 
 * into...
 */
void ssc_store_pending_auth(ssc_t *self, ssc_oper_t *op, sip_t const *sip, tagi_t *tags)
{
  su_home_t *home = self->ssc_home;
  ssc_auth_item_t *authitem = NULL;
  sip_from_t const *sipfrom = sip->sip_from;
  sip_www_authenticate_t const *wa = sip->sip_www_authenticate;
  sip_proxy_authenticate_t const *pa = sip->sip_proxy_authenticate;

  tl_gets(tags, 
	  SIPTAG_WWW_AUTHENTICATE_REF(wa),
	  SIPTAG_PROXY_AUTHENTICATE_REF(pa),
	  TAG_NULL());

  /*printf("%s: %s was unauthorized\n", self->ssc_name, op->op_method_name);*/

  if (wa) {
    sl_header_print(stdout, "Server auth: %s\n", (sip_header_t *)wa);
    authitem = priv_store_pending_auth(home, wa->au_scheme, wa->au_params);
    priv_attach_op_and_username(self, authitem, sipfrom, home, op);
  }
  
  if (pa) {
    sl_header_print(stdout, "Proxy auth: %s\n", (sip_header_t *)pa);
    authitem = priv_store_pending_auth(home, pa->au_scheme, pa->au_params);
    priv_attach_op_and_username(self, authitem, sipfrom, home, op);
  }

  if (authitem) {
    if (self->ssc_auth_req_cb)
      self->ssc_auth_req_cb (self, authitem, self->ssc_cb_context);
  }
}


/**
 * Parses domain part of SIP address given in 'sip_aor'.
 * The return substring is duplicated using 'home' and
 * the ownership is transfered to the caller.
 */
static char *priv_parse_domain(su_home_t *home, const char *sip_aor)
{
  char *result = NULL, *i;

  /* remove sip prefix */
  if (strncmp("sip:", sip_aor, 4) == 0) {
    sip_aor += 4;
  }

  /* skip userinfo */
  if (strstr(sip_aor, "@")) {
    while (*sip_aor && *sip_aor++ != '@');
  }
  
  /* copy rest of the string */
  result = su_strdup(home, sip_aor);

  /* mark end (at port or uri-parameters defs) */
  for (i = result; *i ; i++) {
    if (*i == ';' || *i == ':') *i = 0;
  }

  return result;
}

/**
 * Callback for events delivered by the SIP stack.
 *
 * See libsofia-sip-ua/nua/nua.h documentation.
 */
static void priv_callback(nua_event_t event,
			  int status, char const *phrase,
			  nua_t *nua, ssc_t *ssc,
			  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
			  tagi_t tags[])
{
  g_return_if_fail(ssc);

  switch (event) {
  case nua_r_shutdown:    
    ssc_r_shutdown(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_get_params:    
    ssc_r_get_params(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_register:
    ssc_r_register(status, phrase, nua, ssc, nh, op, sip, tags);
    break;
    
  case nua_r_unregister:
    ssc_r_unregister(status, phrase, nua, ssc, nh, op, sip, tags);
    break;
    
  case nua_i_options:
    ssc_i_options(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_options:
    ssc_r_options(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_invite:
    ssc_r_invite(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_fork:
    ssc_i_fork(status, phrase, nua, ssc, nh, op, sip, tags);
    break;
    
  case nua_i_invite:
    ssc_i_invite(nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_prack:
    ssc_i_prack(nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_state:
    ssc_i_state(status, phrase, nua, ssc, nh, op, sip, tags);
    break;
    
  case nua_r_bye:
    ssc_r_bye(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_bye:
    ssc_i_bye(nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_message:
    ssc_r_message(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_message:
    ssc_i_message(nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_info:
    ssc_r_info(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_info:
    ssc_i_info(nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_refer:
    ssc_r_refer(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_refer:
    ssc_i_refer(nua, ssc, nh, op, sip, tags);
    break;
     
  case nua_r_subscribe:
    ssc_r_subscribe(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_unsubscribe:
    ssc_r_unsubscribe(status, phrase, nua, ssc, nh, op, sip, tags);
    break;

  case nua_r_publish:
    ssc_r_publish(status, phrase, nua, ssc, nh, op, sip, tags);
    break;
    
  case nua_r_notify:
    ssc_r_notify(status, phrase, nua, ssc, nh, op, sip, tags);
    break;
     
  case nua_i_notify:
    ssc_i_notify(nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_cancel:
    ssc_i_cancel(nua, ssc, nh, op, sip, tags);
    break;

  case nua_i_error:
    ssc_i_error(nua, ssc, nh, op, status, phrase, tags);
    break;

  case nua_i_active:
  case nua_i_ack:
  case nua_i_terminated:
    break;

  default:
    if (status > 100)
      printf("%s: unknown event '%s' (%d): %03d %s\n", 
	     ssc->ssc_name, nua_event_name(event), event, status, phrase);
    else
      printf("%s: unknown event %d\n", ssc->ssc_name, event);

    tl_print(stdout, "", tags);

    if (ssc_oper_find_by_handle(ssc, nh) == NULL) {
      /* note: unknown handle, not associated to any existing 
       *       call, message, registration, etc, so it can
       *       be safely destroyed */
      SU_DEBUG_1(("NOTE: destroying handle %p.\n", nh));
      nua_handle_destroy(nh);
    }

    break;

  }

  if (ssc->ssc_event_cb)
    ssc->ssc_event_cb (ssc, (int)event, ssc->ssc_cb_context);
}

/* ====================================================================== */

int priv_str_chr_count(const char *data, int chr)
{
  int count = 0;
  for (; *data; data++) {
    if (*data == chr) ++count;
  }

  return count;
}

/** 
 * Authenticates an operation (if any unauthenticated operations
 * in the list).
 *
 * @param data formatted string ('k [method:"realm":]user:password')
 */
void ssc_auth(ssc_t *ssc, const char *data)
{
  su_home_t *home = ssc->ssc_home;
  const char *authstring = data;
  char *tmpstr = NULL;
  GList *list = ssc->ssc_auth_pend, *next;
  ssc_auth_item_t *authitem;
  int auth_done = 0, colons = priv_str_chr_count(data, ':');

  while (list && auth_done == 0) {

    authitem = (ssc_auth_item_t*)list->data;
    
    if (ssc_oper_check(ssc, authitem->ssc_op) != NULL) {

      /* XXX: colons in any of the fields, realm, username or 
       *      password, will break the code below */

      if (colons == 0) {
	/* data -> 'password' */
	tmpstr = su_sprintf(home, "%s:%s:%s:%s", 
			    authitem->ssc_scheme,
			    authitem->ssc_realm,
			    authitem->ssc_username,
			    data);
      }
      else if (colons == 1) {
	/* data -> 'user:password' */
	tmpstr = su_sprintf(home, "%s:%s:%s", 
			    authitem->ssc_scheme,
			    authitem->ssc_realm,
			    data);
      }
      
      if (tmpstr)
	authstring = tmpstr;
      
      printf("%s: authenticating '%s' with '%s'.\n", 
	     ssc->ssc_name, authitem->ssc_op->op_method_name, authstring);

      /* XXX: if realm does not match, nua does not notify client about 
       *      the mismatch in any way */
      nua_authenticate(authitem->ssc_op->op_handle, NUTAG_AUTH(authstring), TAG_END());

      auth_done = 1;

      if (tmpstr)
	su_free(home, tmpstr);

      nua_handle_unref(authitem->ssc_op->op_handle);
    }
    else {
      printf("%s: stale authentication challenge '%s', ignoring.\n", 
	     ssc->ssc_name, authitem->ssc_realm);
    }

    /* remove the pending auth item list->data */
    su_free(home, authitem->ssc_scheme);
    su_free(home, authitem->ssc_realm);
    su_free(home, authitem->ssc_username);
    su_free(home, authitem);

    next = g_list_next(list);
    ssc->ssc_auth_pend = g_list_remove_link(ssc->ssc_auth_pend, list);
    list = next;
  }

  if (auth_done == 0)
    printf("%s: No operation to authenticate\n", ssc->ssc_name);
}


/**
 * Prints verbose error information to stdout.
 */
void ssc_i_error(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op, 
		 int status, char const *phrase,
		 tagi_t tags[])
{
  printf("%s: error %03d %s\n", ssc->ssc_name, status, phrase);
}

/**
 * Lists all active operations to stdout.
 */
void ssc_list(ssc_t *ssc)
{
  ssc_oper_t *op;

  printf("%s: listing active handles\n", ssc->ssc_name);
  for (op = ssc->ssc_operations; op; op = op->op_next) {
    if (op->op_ident) {
      printf("\t%s to %s\n", 
	     sip_method_name(op->op_method, op->op_method_name), 
	     op->op_ident);
    }
  }
}

/**
 * Sends an outgoing INVITE request.
 *
 * @param ssc context pointer
 * @param destination SIP URI
 */
void ssc_invite(ssc_t *ssc, const char *destination)
{
  ssc_oper_t *op;

  op = ssc_oper_create(ssc, SIP_METHOD_INVITE, destination, TAG_END());
  if (op) {
    /* SDP O/A note: 
     *  - before issuing nua_invite(), we activate the media 
     *    subsystem (allocates network and  media device resources)
     *  - once the media subsystem is ready, we get a callback
     *  - see also: ssc_i_state(), priv_media_state_cb(), and ssc_answer()
     */ 

    op->op_callstate |= opc_pending;

    g_signal_connect (G_OBJECT (ssc->ssc_media), "state-changed", 
		      G_CALLBACK (priv_media_state_cb), op);
    
#if HAVE_MEDIA_IMPL
    {
      int res;
      /* active media before INVITE */
      res = ssc_media_activate(ssc->ssc_media);
      if (res < 0) {
	printf("%s: ERROR: unable to active media subsystem, aborting session.\n", ssc->ssc_name);
	priv_destroy_oper_with_disconnect (ssc, op);
	/* ssc_oper_destroy(ssc, op); */
      }
      else 
	printf("%s: INVITE to %s pending\n", ssc->ssc_name, op->op_ident);
    }
#else
    printf("%s: WARNING, no media subsystem available, unable start sessions\n", ssc->ssc_name);
#endif
  }
}

/**
 * Callback for an outgoing INVITE request.
 */
void ssc_r_invite(int status, char const *phrase, 
		    nua_t *nua, ssc_t *ssc,
		    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		    tagi_t tags[])
{
  printf("%s: INVITE: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status >= 300) {
    op->op_callstate &= ~opc_sent;
    if (status == 401 || status == 407)
      ssc_store_pending_auth(ssc, op, sip, tags);
  }
}

/**
 * Incoming call fork.
 */
void ssc_i_fork(int status, char const *phrase,
		nua_t *nua, ssc_t *ssc,
		nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		tagi_t tags[])
{
  nua_handle_t *nh2 = NULL;

  printf("%s: call fork: %03d %s\n", ssc->ssc_name, status, phrase);

  /* We just release forked calls. */
  tl_gets(tags, NUTAG_HANDLE_REF(nh2), TAG_END());
  g_return_if_fail(nh2);

  nua_bye(nh2, TAG_END());
  nua_handle_destroy(nh2);
}

/**
 * Incoming INVITE request.
 */
void ssc_i_invite(nua_t *nua, ssc_t *ssc,
		  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		  tagi_t tags[])
{
  /* Incoming call */
  sip_from_t const *from;
  sip_to_t const *to;
  sip_subject_t const *subject;

  g_return_if_fail(sip);

  from = sip->sip_from;
  to = sip->sip_to;
  subject = sip->sip_subject;

  g_return_if_fail(from && to);

  if (op) {
    op->op_callstate |= opc_recv;
  }
  else if ((op = ssc_oper_create_with_handle(ssc, SIP_METHOD_INVITE, nh, from))) {
    op->op_callstate = opc_recv;
  }
  else {
    nua_respond(nh, SIP_500_INTERNAL_SERVER_ERROR, TAG_END());
    nua_handle_destroy(nh);
  }

  if (op) {
    if (op->op_callstate == opc_recv) {
      printf("%s: incoming call\n\tFrom: %s\n", ssc->ssc_name, op->op_ident);
      printf("\tTo: %s%s<" URL_PRINT_FORMAT ">\n",
	     to->a_display ? to->a_display : "", 
	     to->a_display ? " " : "",
	     URL_PRINT_ARGS(to->a_url));
      if (subject)
	printf("\tSubject: %s\n", subject->g_value);

      if (ssc->ssc_autoanswer) {
	ssc_answer(ssc, SIP_200_OK);
      }
      else {
	printf("Please Answer(a), decline(d) or Decline(D) the call\n");
      }
    }
    else {
      printf("%s: re-INVITE from: %s\n", ssc->ssc_name, op->op_ident);
    }
  }
}

/**
 * Callback that triggers the second phase of ssc_answer() and 
 * ssc_invite(). Verifies that the media subsystem has 
 * been activated and we are ready to answer with our SDP.
 */
static void priv_media_state_cb(void* context, guint state, gpointer data)
{
#if HAVE_MEDIA_IMPL
  ssc_oper_t *op = (ssc_oper_t*)data;
  ssc_t *ssc = op->op_ssc;

  g_debug ("%s, state %u", G_STRFUNC, state);

  if (state == sm_local_ready ||
      state == sm_active) {

    /* SDP O/A case 1: outgoing invite
     *  - get a description of the network addresses
     *    and available media and codecs
     *  - pass this information to nua_invite() in the 
     *    SOATAG_USER_SDP_STR() tag
     *  - see also: ssc_i_state() and ssc_answer()
     */ 
    
    if ((op->op_callstate & opc_pending) && 
	ssc_media_is_initialized(ssc->ssc_media)) {
      gchar *l_sdp = NULL;
      
      op->op_callstate &= !opc_pending;
      
      /* get the ports and list of media */
      g_object_get(G_OBJECT(ssc->ssc_media), "localsdp", &l_sdp, NULL);
      
      if (l_sdp) {
	printf("%s: about to make a call with local SDP:\n%s\n", ssc->ssc_name, l_sdp);
      
	nua_invite(op->op_handle,
		   SOATAG_USER_SDP_STR(l_sdp),
		   SOATAG_RTP_SORT(SOA_RTP_SORT_REMOTE),
		   SOATAG_RTP_SELECT(SOA_RTP_SELECT_ALL),
		   TAG_END());
	
	op->op_callstate |= opc_sent;
	printf("%s: INVITE to %s\n", ssc->ssc_name, op->op_ident);
      }
      else {
	op->op_callstate |= opc_none;
	printf("ERROR: no SDP provided by media subsystem, aborting call.\n");
	priv_destroy_oper_with_disconnect (ssc, op);
	/* ssc_oper_destroy(ssc, op); */
      }
    }

    /* SDP O/A note: answering to incoming call (2)
     *  - get a description of the network addresses
     *    and available media and codecs
     *  - pass this information to nua_respond() in
     *    the SOATAG_USER_SDP_STR() tag
     *  - see also: ssc_i_state() and ssc_invite()
     */
    else if (op->op_callstate & opc_recv) {
      char *l_sdp_str = NULL;
      int status = ssc->ssc_ans_status;
      char const *phrase = ssc->ssc_ans_phrase;
      
      /* get the ports and list of media */
      g_object_get(G_OBJECT(ssc->ssc_media), "localsdp", &l_sdp_str, NULL);

      printf("%s: about to respond with local SDP:\n%s\n",
	     ssc->ssc_name, l_sdp_str);

      if (l_sdp_str) {
	if (status >= 200 && status < 300)
	  op->op_callstate |= opc_sent;
	else
	  op->op_callstate = opc_none;
	nua_respond(op->op_handle, status, phrase, 
		    SOATAG_USER_SDP_STR(l_sdp_str),
		    SOATAG_RTP_SORT(SOA_RTP_SORT_REMOTE),
		    SOATAG_RTP_SELECT(SOA_RTP_SELECT_ALL),
		    TAG_END());
      }
      else {
	printf("ERROR: no SDP provided by media subsystem, unable to answer call.");
	op->op_callstate = opc_none;
	nua_respond(op->op_handle, 500, "Not Acceptable Here", TAG_END());
      }
    }
  }
  else if (state == sm_error) {
    printf("%s: Media subsystem reported an error.\n", ssc->ssc_name);
    ssc_media_deactivate(ssc->ssc_media);
    priv_destroy_oper_with_disconnect (ssc, op);
    /* ssc_oper_destroy (ssc, op); */
  }
  
  if (ssc->ssc_media_state_cb)
    ssc->ssc_media_state_cb (ssc, op, state, ssc->ssc_cb_context);

#endif /* HAVE_MEDIA_IMPL */
}

/** 
 * Answers a call (processed in two phases). 
 *
 * See also ssc_i_invite().
 */
void ssc_answer(ssc_t *ssc, int status, char const *phrase)
{
  ssc_oper_t *op = ssc_oper_find_unanswered(ssc);

  if (op != NULL) {

    /* store status and phrase for later use */
    ssc->ssc_ans_status = status;
    ssc->ssc_ans_phrase = phrase;

    /* SDP O/A note: 
     *  - before issuing nua_respond(), we activate the media 
     *    subsystem (allocates network and media device resources)
     *  - this is an async operation so we need to use a callback
     */ 

#if HAVE_MEDIA_IMPL
    /* active media before sending offer */
    if (status >= 200 && status < 300) {
      int res;

      g_signal_connect (G_OBJECT (ssc->ssc_media), "state-changed", 
			G_CALLBACK (priv_media_state_cb), op);

      /* active media before answering */
      res = ssc_media_activate(ssc->ssc_media);
      if (res < 0) {
	printf("%s: ERROR: unable to active media subsystem, unable to answer session.\n", ssc->ssc_name);
	priv_destroy_oper_with_disconnect (ssc, op);
	/* ssc_oper_destroy(ssc, op); */
      }
      else 
	printf("%s: answering to the offer received from %s\n", ssc->ssc_name, op->op_ident);
    }
    else {
      /* call rejected */
      nua_respond(op->op_handle, status, phrase, TAG_END());
      priv_destroy_oper_with_disconnect (ssc, op);
      /* ssc_oper_destroy(ssc, op); */
    }
#else
    printf("%s: WARNING, no media subsystem available, unable to answer\n", ssc->ssc_name);
#endif /* HAVE_MEDIA_IMPL */

  }
  else
    printf("%s: no call to answer\n", ssc->ssc_name);
}

/**
 * Converts 'mode' to a string.
 */
char const *cli_active(int mode)
{
  switch (mode) {
  case nua_active_inactive: return "inactive";
  case nua_active_sendonly: return "sendonly";
  case nua_active_recvonly: return "recvonly";
  case nua_active_sendrecv: return "sendrecv";
  default:                  return "none";
  }
}

/**
 * Incoming PRACK request.
 */
void ssc_i_prack(nua_t *nua, ssc_t *ssc,
		 nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		 tagi_t tags[])
{
  sip_rack_t const *rack;

  g_return_if_fail(sip);

  rack = sip->sip_rack;

  printf("%s: received PRACK %u\n", ssc->ssc_name, rack ? rack->ra_response : 0);

  if (op == NULL)
    nua_handle_destroy(nh);
}

/**
 * Callback issued for any change in operation state.
 */
void ssc_i_state(int status, char const *phrase, 
		 nua_t *nua, ssc_t *ssc,
		 nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		 tagi_t tags[])
{
  char const *l_sdp = NULL, *r_sdp = NULL;
  int audio = nua_active_inactive, video = nua_active_inactive, chat = nua_active_inactive;
  int offer_recv = 0, answer_recv = 0, offer_sent = 0, answer_sent = 0;
  int ss_state = nua_callstate_init;

  g_return_if_fail(op);

  tl_gets(tags, 
	  NUTAG_CALLSTATE_REF(ss_state),
	  NUTAG_OFFER_RECV_REF(offer_recv),
	  NUTAG_ANSWER_RECV_REF(answer_recv),
	  NUTAG_OFFER_SENT_REF(offer_sent),
	  NUTAG_ANSWER_SENT_REF(answer_sent),
	  SOATAG_LOCAL_SDP_STR_REF(l_sdp),
	  SOATAG_REMOTE_SDP_STR_REF(r_sdp),
	  TAG_END());

  if (l_sdp) {
    g_return_if_fail(answer_sent || offer_sent);
    g_object_set(G_OBJECT(ssc->ssc_media), "localsdp", l_sdp, NULL);
    /* printf("%s: local SDP updated:\n%s\n\n", ssc->ssc_name, l_sdp); */
  }
  
  if (r_sdp) {
    g_return_if_fail(answer_recv || offer_recv);
    g_object_set(G_OBJECT(ssc->ssc_media), "remotesdp", r_sdp, NULL);
    /* printf("%s: remote SDP updated:\n%s\n\n", ssc->ssc_name, r_sdp); */
  }

  switch ((enum nua_callstate)ss_state) {
  case nua_callstate_received:
    /* In auto-alert mode, we don't need to call nua_respond(), see NUTAG_AUTOALERT() */
    /* nua_respond(nh, SIP_180_RINGING, TAG_END()); */
    break;

  case nua_callstate_early:
    /* nua_respond(nh, SIP_200_OK, TAG_END()); */
    
  case nua_callstate_completing:
    /* In auto-ack mode, we don't need to call nua_ack(), see NUTAG_AUTOACK() */
    break;

  case nua_callstate_ready:
    tl_gets(tags, 
	    NUTAG_ACTIVE_AUDIO_REF(audio), 
	    NUTAG_ACTIVE_VIDEO_REF(video), 
	    NUTAG_ACTIVE_CHAT_REF(chat), 
	    TAG_END());

    op->op_callstate = opc_active;

    if (op->op_prev_state != ss_state) {
      /* note: only print if state has changed */
      printf("%s: call to %s is active => '%s'\n\taudio %s, video %s, chat %s.\n", 
	     ssc->ssc_name, op->op_ident, nua_callstate_name(ss_state),
	     cli_active(audio), cli_active(video), cli_active(chat));
      op->op_prev_state = ss_state;
    }

    /* SDP O/A note: 
     *  - check the O/A state and whether local and/or remote SDP 
     *    is available (and whether it is updated)
     *  - inform media subsystem of the changes in configuration
     *  - check fro NUTAG_ACTIVE flags for changes in 
     *    session status (especially call hold)
     *  - see also: ssc_i_state() and ssc_invite()
     */ 

    break;

  case nua_callstate_terminated:
    if (op) {
      printf("%s: call to %s is terminated\n", ssc->ssc_name, op->op_ident);
      op->op_callstate = 0;
      priv_destroy_oper_with_disconnect (ssc, op);
      /* ssc_oper_destroy(ssc, op); */

#if HAVE_MEDIA_IMPL
      /* SDP O/A note: 
       * - de-active media subsystem */
      if (ssc_media_is_initialized(ssc->ssc_media) == TRUE)
	ssc_media_deactivate(ssc->ssc_media);
#endif

    }
    break;

  default:
    break;
  }

  if (ssc->ssc_call_state_cb)
      ssc->ssc_call_state_cb (ssc, op, ss_state, ssc->ssc_cb_context);
}

/**
 * Sends a BYE request to an active operation (finds the
 * first ).
 */
void ssc_bye(ssc_t *ssc)
{
  ssc_oper_t *op = ssc_oper_find_call(ssc);

  if (op) {
    printf("%s: BYE to %s\n", ssc->ssc_name, op->op_ident);
    nua_bye(op->op_handle, TAG_END());
    op->op_callstate = 0;
  }
  else {
    printf("%s: no call to bye\n", ssc->ssc_name);
  }
}

/**
 * Callback for an outgoing BYE request.
 */
void ssc_r_bye(int status, char const *phrase, 
	       nua_t *nua, ssc_t *ssc,
	       nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
	       tagi_t tags[])
{
  assert(op); assert(op->op_handle == nh);

  printf("%s: BYE: %03d %s\n", ssc->ssc_name, status, phrase);
  if (status < 200)
    return;
}

/**
 * Incoming BYE request. Note, call state related actions are
 * done in the ssc_i_state() callback.
 */
void ssc_i_bye(nua_t *nua, ssc_t *ssc,
		 nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		 tagi_t tags[])
{
  assert(op); assert(op->op_handle == nh);

  printf("%s: BYE received\n", ssc->ssc_name);
}

/**
 * Cancels a call operation currently in progress (if any).
 */
void ssc_cancel(ssc_t *ssc)
{
  ssc_oper_t *op = ssc_oper_find_call_in_progress(ssc);

  if (op) {
    printf("%s: CANCEL %s to %s\n", 
	   ssc->ssc_name, op->op_method_name, op->op_ident);
    nua_cancel(op->op_handle, TAG_END());
  }
  else if ((op = ssc_oper_find_call_embryonic(ssc))) {
    printf("%s: reject REFER to %s\n", 
	   ssc->ssc_name, op->op_ident);
    nua_cancel(op->op_handle, TAG_END());
  }
  else {
    printf("%s: no call to CANCEL\n", ssc->ssc_name);
  }
}

/**
 * Incoming CANCEL.
 */
void ssc_i_cancel(nua_t *nua, ssc_t *ssc,
		    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		    tagi_t tags[])
{
  assert(op); assert(op->op_handle == nh);

  printf("%s: CANCEL received\n", ssc->ssc_name);
}

void ssc_zap(ssc_t *ssc, char *which)
{
  ssc_oper_t *op;

  op = ssc_oper_create(ssc, sip_method_unknown, NULL, NULL, TAG_END());

  if (op) {
    printf("%s: zap %s to %s\n", ssc->ssc_name, 
	   op->op_method_name, op->op_ident);
    priv_destroy_oper_with_disconnect (ssc, op);
    /* ssc_oper_destroy(ssc, op); */
  }
  else
      printf("No operations to zap\n");
}

/**
 * Sends an option request to 'destionation'.
 */
void ssc_options(ssc_t *ssc, char *destination)
{
  ssc_oper_t *op = ssc_oper_create(ssc, SIP_METHOD_OPTIONS, destination,
				   TAG_END());

  if (op) {
    printf("%s: OPTIONS to %s\n", ssc->ssc_name, op->op_ident);
    nua_options(op->op_handle, TAG_END());
  }
}

/**
 * Callback to an incoming OPTIONS request.
 */
void ssc_i_options(int status, char const *phrase,
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  printf("%s: OPTIONS received\n", ssc->ssc_name);
}

/**
 * Callback to an outgoing OPTIONS request.
 */
void ssc_r_options(int status, char const *phrase,
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  printf("%s: OPTIONS %d %s\n", ssc->ssc_name, status, phrase);

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
}

void ssc_message(ssc_t *ssc, const char *destination, const char *msg)
{
  ssc_oper_t *op = ssc_oper_create(ssc, SIP_METHOD_MESSAGE, destination, 
				   TAG_END());

  if (op) {

    printf("%s: sending message to %s\n", ssc->ssc_name, op->op_ident);
    
    nua_message(op->op_handle,
		SIPTAG_CONTENT_TYPE_STR("text/plain"),
		SIPTAG_PAYLOAD_STR(msg),
		TAG_END());
  }
}

void ssc_r_message(int status, char const *phrase,
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  printf("%s: MESSAGE: %d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
}

void ssc_i_message(nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  /* Incoming message */
  sip_from_t const *from;
  sip_to_t const *to;
  sip_subject_t const *subject;

  assert(sip);

  from = sip->sip_from;
  to = sip->sip_to;
  subject = sip->sip_subject;

  assert(from && to);

  printf("%s: new message \n", ssc->ssc_name);
  printf("\tFrom: %s%s" URL_PRINT_FORMAT "\n", 
	 from->a_display ? from->a_display : "", from->a_display ? " " : "",
	 URL_PRINT_ARGS(from->a_url));
  if (subject) 
    printf("\tSubject: %s\n", subject->g_value);
  ssc_print_payload(ssc, sip->sip_payload);

  if (op == NULL)
    op = ssc_oper_create_with_handle(ssc, SIP_METHOD_MESSAGE, nh, from);
  if (op == NULL)
    nua_handle_destroy(nh);
}

void ssc_info(ssc_t *ssc, const char *destination, const char *msg)
{
  ssc_oper_t *op = ssc_oper_find_call(ssc);
   
  if (op) {
    printf("%s: sending INFO to %s\n", ssc->ssc_name, op->op_ident);

    nua_info(op->op_handle,
	     SIPTAG_CONTENT_TYPE_STR("text/plain"),
	     SIPTAG_PAYLOAD_STR(msg),
	     TAG_END());
  }
  else {
    printf("INFO can be send only within an existing call\n");
  }
}

void ssc_r_info(int status, char const *phrase,
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  printf("%s: INFO: %d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
}

void ssc_i_info(nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  /* Incoming info */
  sip_from_t const *from;
  sip_to_t const *to;
  sip_subject_t const *subject;

  assert(sip);

  from = sip->sip_from;
  to = sip->sip_to;
  subject = sip->sip_subject;

  assert(from && to);

  printf("%s: new info \n", ssc->ssc_name);
  printf("\tFrom: %s%s" URL_PRINT_FORMAT "\n", 
	 from->a_display ? from->a_display : "", from->a_display ? " " : "",
	 URL_PRINT_ARGS(from->a_url));
  ssc_print_payload(ssc, sip->sip_payload);

  if (op == NULL)
    op = ssc_oper_create_with_handle(ssc, SIP_METHOD_INFO, nh, from);
  if (op == NULL)
    nua_handle_destroy(nh);
}

/*=======================================*/
/*REFER */
void ssc_refer(ssc_t *ssc, const char *destination, const char *to_address)
{
   /* Send a refer */
   ssc_oper_t *op = ssc_oper_find_call(ssc);
   
   if (op == NULL) 
     op = ssc_oper_create(ssc, SIP_METHOD_REFER, destination, TAG_END());

   if (op) {
      printf("%s: Refer to %s\n", ssc->ssc_name, op->op_ident);

      nua_refer(op->op_handle,
		SIPTAG_REFER_TO_STR(to_address),
		TAG_END());
   }
}

/*---------------------------------------*/
void ssc_r_refer(int status, char const *phrase,
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  /* Respond to refer */
  printf("%s: refer: %d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
}

/*---------------------------------------*/
void ssc_i_refer(nua_t *nua, ssc_t *ssc,
		 nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		 tagi_t tags[])
{
  /* Incoming refer */
  sip_from_t const *from;
  sip_to_t const *to;
  sip_refer_to_t const *refer_to;
  ssc_oper_t *op2;
  char *refer_to_str;

  assert(sip);

  from = sip->sip_from;
  to = sip->sip_to;
  refer_to = sip->sip_refer_to;

  assert(from && to);

  printf("%s: refer to " URL_PRINT_FORMAT " from %s%s" URL_PRINT_FORMAT "\n", 
	 ssc->ssc_name,
	 URL_PRINT_ARGS(from->a_url),
	 from->a_display ? from->a_display : "", from->a_display ? " " : "",
	 URL_PRINT_ARGS(from->a_url));
   
  printf("Please follow(i) or reject(c) the refer\n");
   
   if(refer_to->r_url->url_type == url_sip) {
      refer_to_str = sip_header_as_string(ssc->ssc_home, (sip_header_t*)refer_to);
      op2 = ssc_oper_create(ssc, SIP_METHOD_INVITE, refer_to_str,
			    NUTAG_NOTIFY_REFER(nh), TAG_END());
      su_free(ssc->ssc_home, refer_to_str);
   }
   else {
     printf("\nPlease Refer to URI: "URL_PRINT_FORMAT"\n", URL_PRINT_ARGS(refer_to->r_url));
   }
}

/*---------------------------------------*/
void ssc_hold(ssc_t *ssc, char *destination, int hold)
{
   /* XXX: hold not supported at the moment */
#if 0

   /* Put a media stream on hold */
   ssc_oper_t *op = ssc_oper_find_call(ssc);

   if (op) {
      printf("%s: Sending re-INVITE with %s to %s\n", 
	     ssc->ssc_name, hold ? "hold" : "unhold", op->op_ident);

      nua_invite(op->op_handle, NUTAG_HOLD(hold), TAG_END());
      
      op->op_callstate = opc_sent_hold;
   }
   else {
     printf("%s: no call to put on hold\n", ssc->ssc_name);
   }
#else
   printf("%s: call hold feature not available.\n", ssc->ssc_name);
#endif
}

/*---------------------------------------*/
void ssc_subscribe(ssc_t *ssc, char *destination)
{
  ssc_oper_t *op;
  char const *event = "presence";
  char const *supported = NULL;

  if (strncasecmp(destination, "list ", 5) == 0) {
    destination += 5;
    while (*destination == ' ')
      destination++;
    supported = "eventlist";
  }

  op = ssc_oper_create(ssc, SIP_METHOD_SUBSCRIBE, destination, TAG_END());

  if (op) {
    printf("%s: SUBSCRIBE %s to %s\n", ssc->ssc_name, event, op->op_ident);
    nua_subscribe(op->op_handle, 
		  SIPTAG_EXPIRES_STR("3600"),
		  SIPTAG_ACCEPT_STR("application/cpim-pidf+xml;q=0.5, "
				    "application/pidf-partial+xml"),
		  TAG_IF(supported, 
			 SIPTAG_ACCEPT_STR("multipart/related, "
					   "application/rlmi+xml")),
		  SIPTAG_SUPPORTED_STR(supported),
		  SIPTAG_EVENT_STR(event),
		  TAG_END());
  }
}

void ssc_watch(ssc_t *ssc, char *event)
{
  ssc_oper_t *op;
  char *destination;

  destination = strchr(event, ' ');
  while (destination && *destination == ' ')
    *destination++ = '\0';

  op = ssc_oper_create(ssc, SIP_METHOD_SUBSCRIBE, destination, TAG_END());

  if (op) {
    printf("%s: SUBSCRIBE %s to %s\n", ssc->ssc_name, event, op->op_ident);
    nua_subscribe(op->op_handle, 
		  SIPTAG_EVENT_STR(event),
		  TAG_END());
  }
}

void ssc_r_subscribe(int status, char const *phrase,
		     nua_t *nua, ssc_t *ssc,
		     nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		     tagi_t tags[])
{
  printf("%s: SUBSCRIBE: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;
  if (status >= 300)
    op->op_persistent = 0;
  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
}
/*---------------------------------------*/
void ssc_notify(ssc_t *ssc, char *destination)
{
  ssc_oper_t *op = ssc_oper_find_call_embryonic(ssc);

  if (op) {
    printf("%s: not follow refer, NOTIFY(503)\n", ssc->ssc_name);

    nua_cancel(op->op_handle, TAG_END());
    ssc_oper_destroy(ssc, op);
  }
  else {
    printf("%s: no REFER to NOTIFY\n", ssc->ssc_name);
  }
}
/*---------------------------------------*/
void ssc_i_notify(nua_t *nua, ssc_t *ssc,
		  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		  tagi_t tags[])
{
  if (sip) {
    sip_from_t const *from = sip->sip_from;
    sip_event_t const *event = sip->sip_event;
    sip_content_type_t const *content_type = sip->sip_content_type;
    sip_payload_t const *payload = sip->sip_payload;

    if (op)
      printf("%s: NOTIFY from %s\n", ssc->ssc_name, op->op_ident);
    else
      printf("%s: rogue NOTIFY from " URL_PRINT_FORMAT "\n", 
	     ssc->ssc_name, URL_PRINT_ARGS(from->a_url));    
    if (event)
      printf("\tEvent: %s\n", event->o_type);
    if (content_type)
      printf("\tContent type: %s\n", content_type->c_type);
    fputs("\n", stdout);
    ssc_print_payload(ssc, payload);
  }
  else
    printf("%s: SUBSCRIBE/NOTIFY timeout for %s\n", ssc->ssc_name, op->op_ident);
}

/*---------------------------------------*/
void ssc_r_notify(int status, char const *phrase,
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  /* Respond to notify */
  printf("%s: notify: %d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
}
/*---------------------------------------*/

void ssc_unsubscribe(ssc_t *ssc, char *destination)
{
  ssc_oper_t *op = ssc_oper_find_by_method(ssc, sip_method_subscribe);

  if (op) {
    printf("%s: un-SUBSCRIBE to %s\n", ssc->ssc_name, op->op_ident);
    nua_unsubscribe(op->op_handle, TAG_END());
  }
  else
    printf("%s: no subscriptions\n", ssc->ssc_name);
}

void ssc_r_unsubscribe(int status, char const *phrase,
		       nua_t *nua, ssc_t *ssc,
		       nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		       tagi_t tags[])
{
  printf("%s: un-SUBSCRIBE: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  ssc_oper_destroy(ssc, op);
}

void ssc_register(ssc_t *ssc, const char *registrar)
{
  char *address;
  ssc_oper_t *op;

  if (!registrar && (op = ssc_oper_find_by_method(ssc, sip_method_register))) {
    printf("%s: REGISTER %s - updating existing registration\n", ssc->ssc_name, op->op_ident);
    nua_register(op->op_handle, TAG_NULL());
    return;
  }

  address = su_strdup(ssc->ssc_home, ssc->ssc_address);

  if ((op = ssc_oper_create(ssc, SIP_METHOD_REGISTER, address, TAG_END()))) {
    printf("%s: REGISTER %s - registering address to network\n", ssc->ssc_name, op->op_ident);
    nua_register(op->op_handle, 
		 TAG_IF(registrar, NUTAG_REGISTRAR(registrar)),
		 NUTAG_M_FEATURES("expires=180"),
		 TAG_NULL());
  }

  su_free(ssc->ssc_home, address);
}

void ssc_r_register(int status, char const *phrase, 
		    nua_t *nua, ssc_t *ssc,
		    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		    tagi_t tags[])
{
  sip_contact_t *m = sip ? sip->sip_contact : NULL;

  printf("%s: REGISTER: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
  else if (status >= 300)
    ssc_oper_destroy(ssc, op);
  else if (status == 200) {
    printf("%s: succesfully registered %s to network\n", ssc->ssc_name, ssc->ssc_address);
    if (ssc->ssc_registration_cb)
      ssc->ssc_registration_cb (ssc, 1, ssc->ssc_cb_context);
    for (m = sip ? sip->sip_contact : NULL; m; m = m->m_next)
      sl_header_print(stdout, "\tContact: %s\n", (sip_header_t *)m);

  }

}

void ssc_unregister(ssc_t *ssc, const char *registrar)
{
  ssc_oper_t *op;

  if (!registrar && (op = ssc_oper_find_by_method(ssc, sip_method_register))) {
    printf("%s: un-REGISTER %s\n", ssc->ssc_name, op->op_ident);
    nua_unregister(op->op_handle, TAG_NULL());
    return;
  }
  else {
    char *address = su_strdup(ssc->ssc_home, ssc->ssc_address);
    op = ssc_oper_create(ssc, SIP_METHOD_REGISTER, address, TAG_END());
    su_free(ssc->ssc_home, address);

    if (op) {
      printf("%s: un-REGISTER %s%s%s\n", ssc->ssc_name, 
	     op->op_ident, 
	     registrar ? " at " : "", 
	     registrar ? registrar : "");
      nua_unregister(op->op_handle,
		     TAG_IF(registrar, NUTAG_REGISTRAR(registrar)),
		     SIPTAG_CONTACT_STR("*"),
		     SIPTAG_EXPIRES_STR("0"),
		     TAG_NULL());
      return;
    }
  }
}


void ssc_r_unregister(int status, char const *phrase, 
		      nua_t *nua, ssc_t *ssc,
		      nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		      tagi_t tags[])
{
  sip_contact_t *m;

  printf("%s: un-REGISTER: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 200) {
    if (ssc->ssc_registration_cb)
      ssc->ssc_registration_cb (ssc, 0, ssc->ssc_cb_context);
    for (m = sip ? sip->sip_contact : NULL; m; m = m->m_next)
      sl_header_print(stdout, "\tContact: %s\n", (sip_header_t *)m);
  }

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
  else
    ssc_oper_destroy(ssc, op);

}


void ssc_publish(ssc_t *ssc, const char *note)
{
  ssc_oper_t *op;
  sip_payload_t *pl = NULL;
  char *address;
  char *xmlnote = NULL;
  int open;

  open = note == NULL || note[0] != '-';

  if (note && strcmp(note, "-") != 0)
    xmlnote = su_sprintf(ssc->ssc_home, "<note>%s</note>\n", 
			 open ? note : note + 1);

  pl = sip_payload_format
    (ssc->ssc_home, 
     "<?xml version='1.0' encoding='UTF-8'?>\n"
     "<presence xmlns='urn:ietf:params:xml:ns:cpim-pidf'\n"
     "          entity='%s'>\n"
     "  <tuple id='%s'>\n"
     "    <status><basic>%s</basic></status>\n"
     "%s"
     "  </tuple>\n"
     "</presence>\n",
     ssc->ssc_address, ssc->ssc_name, 
     open ? "open" : "closed", 
     xmlnote ? xmlnote : "");

  if ((op = ssc_oper_find_by_method(ssc, sip_method_publish))) {
    printf("%s: %s %s\n", ssc->ssc_name, op->op_method_name, op->op_ident);
    nua_publish(op->op_handle, 
		SIPTAG_PAYLOAD(pl),
		TAG_IF(pl, SIPTAG_CONTENT_TYPE_STR("application/cpim-pidf+xml")),
		TAG_NULL());

    su_free(ssc->ssc_home, pl);
    return;
  }

  address = su_strdup(ssc->ssc_home, ssc->ssc_address);

  if ((op = ssc_oper_create(ssc, SIP_METHOD_PUBLISH, address, 
			    SIPTAG_EVENT_STR("presence"),
			    TAG_END()))) {
    printf("%s: %s %s\n", ssc->ssc_name, op->op_method_name, op->op_ident);
    nua_publish(op->op_handle, 
		SIPTAG_CONTENT_TYPE_STR("application/cpim-pidf+xml"),
		SIPTAG_PAYLOAD(pl),
		TAG_END());
  }

  su_free(ssc->ssc_home, pl);
  su_free(ssc->ssc_home, address);
}

void ssc_unpublish(ssc_t *ssc)
{
  ssc_oper_t *op;
  char *address;

  if ((op = ssc_oper_find_by_method(ssc, sip_method_publish))) {
    printf("%s: %s %s\n", ssc->ssc_name, op->op_method_name, op->op_ident);
    nua_publish(op->op_handle, 
		SIPTAG_EXPIRES_STR("0"),
		TAG_NULL());
    return;
  }

  address = su_strdup(ssc->ssc_home, ssc->ssc_address);

  if ((op = ssc_oper_create(ssc, SIP_METHOD_PUBLISH, address, 
			    SIPTAG_EVENT_STR("presence"),
			    TAG_END()))) {
    printf("%s: un-%s %s\n", ssc->ssc_name, op->op_method_name, op->op_ident);
    nua_publish(op->op_handle, 
		SIPTAG_EXPIRES_STR("0"),
		TAG_END());
  }

  su_free(ssc->ssc_home, address);
}

/**
 * Sets the public address used for invites, messages,
 * registrations, etc method.
 */
void ssc_set_public_address(ssc_t *ssc, const char *address)
{
  if (address) {
    su_free(ssc->ssc_home, ssc->ssc_address);
    ssc->ssc_address = su_strdup(ssc->ssc_home, address);

    nua_set_params(ssc->ssc_nua,
		   SIPTAG_FROM_STR(ssc->ssc_address),
		   TAG_NULL());
  }
}

/**
 * Callback for an outgoing PUBLISH request.
 */
void ssc_r_publish(int status, char const *phrase, 
		   nua_t *nua, ssc_t *ssc,
		   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		   tagi_t tags[])
{
  printf("%s: PUBLISH: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;

  if (status == 401 || status == 407)
    ssc_store_pending_auth(ssc, op, sip, tags);
  else if (status >= 300)
    ssc_oper_destroy(ssc, op);
  else if (!sip->sip_expires || sip->sip_expires->ex_delta == 0)
    ssc_oper_destroy(ssc, op);
}

void ssc_r_shutdown(int status, char const *phrase, 
		    nua_t *nua, ssc_t *ssc,
		    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		    tagi_t tags[])
{
  printf("%s: nua_shutdown: %03d %s\n", ssc->ssc_name, status, phrase);

  if (status < 200)
    return;
  
  if (ssc->ssc_exit_cb)
    ssc->ssc_exit_cb();
}

/**
 * Result callback for nua_r_get_params request.
 */
void ssc_r_get_params(int status, char const *phrase, 
		      nua_t *nua, ssc_t *ssc,
		      nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
		      tagi_t tags[])
{
  sip_from_t const *from = NULL;

  printf("%s: nua_r_getparams: %03d %s\n", ssc->ssc_name, status, phrase);
  tl_print(stdout, "", tags);

  tl_gets(tags, SIPTAG_FROM_REF(from), TAG_END());

  if (from) {
    char const *new_address = 
      sip_header_as_string(ssc->ssc_home, (sip_header_t *)from);
    if (new_address) {
      su_free(ssc->ssc_home, (char *)ssc->ssc_address);
      ssc->ssc_address = su_strdup(ssc->ssc_home, new_address);
    }      
  }

  printf("\nStarting sofsip-cli in interactive mode. Issue 'h' to get list of available commands.\n");
}

/**
 * Prints SIP message payload to stdout.
 */
void ssc_print_payload(ssc_t *ssc, sip_payload_t const *pl)
{
  fputs("\n", stdout); 
  if (pl) {
    fwrite(pl->pl_data, pl->pl_len, 1, stdout);
    if (pl->pl_len < 1 || 
	(pl->pl_data[pl->pl_len - 1] != '\n' ||
	 pl->pl_data[pl->pl_len - 1] != '\r'))
      fputs("\n\n", stdout);
    else
      fputs("\n", stdout);
  }
}

void ssc_print_settings(ssc_t *ssc)
{
  printf("SIP address...........: %s\n", ssc->ssc_address);
}

void ssc_param(ssc_t *ssc, char *param, char *s)
{
  tag_type_t tag = NULL, *list;
  tag_value_t value = 0;
  char *ns = NULL, *sep;
  su_home_t home[1] = { SU_HOME_INIT(home) };
  int scanned;

  enter;

  if ((sep = strstr(param, "::"))) {
    ns = param, *sep = '\0', param = sep + 2;
  } else if ((sep = strstr(param, "."))) {
    ns = param, *sep = '\0', param = sep + 1;
  } else if ((sep = strstr(param, ":"))) {
    ns = param, *sep = '\0', param = sep + 1;
  }

  if (!ns || strcmp(ns, "nua") == 0)
      for (list = nua_tag_list; (tag = *list); list++) {
	if (strcmp(tag->tt_name, param) == 0) {
	  ns = "found";
	  break;
	}
      }
  if (!ns || strcmp(ns, "nta") == 0) 
      for (list = nta_tag_list; (tag = *list); list++) {
	if (strcmp(tag->tt_name, param) == 0) {
	  ns = "found";
	  break;
	}
      }
  if (!ns || strcmp(ns, "sip") == 0) 
      for (list = sip_tag_list; (tag = *list); list++) {
	if (strcmp(tag->tt_name, param) == 0) {
	  ns = "found";
	  break;
	}
      }


  if (!tag) {
    printf("sofsip: unknown parameter %s::%s\n",  
	   ns ? ns : "", param);
    return;
  }

  scanned = t_scan(tag, home, s, &value);
  if (scanned <= 0) {
    printf("sofsip: invalid value for %s::%s\n",  
	   ns ? ns : "", param);
    return;
  }

  nua_set_params(ssc->ssc_nua, tag, value, TAG_NULL());
  nua_get_params(ssc->ssc_nua, tag, (tag_value_t)0, TAG_NULL());

  su_home_deinit(home);
}

void ssc_shutdown(ssc_t *ssc)
{
  enter;

  printf("%s: quitting (this can take some time)\n", ssc->ssc_name);

  nua_shutdown(ssc->ssc_nua);
}

