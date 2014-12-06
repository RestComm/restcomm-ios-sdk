/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005-2006 Nokia Corporation.
 *
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

#ifndef HAVE_SSC_SIP_H
#define HAVE_SSC_SIP_H

/**@file ssc_sip.h Interface towards Sofia-SIP
 *
 * @author Kai Vehmanen <Kai.Vehmanen@nokia.com>
 * @author Pekka Pessi <Pekka.Pessi@nokia.com>
 */

typedef struct ssc_s ssc_t;
typedef struct ssc_auth_item_s ssc_auth_item_t;
typedef struct ssc_conf_s ssc_conf_t;

/* define type of context pointers for callbacks */
#define NUA_MAGIC_T     ssc_t
#define SOA_MAGIC_T     ssc_t

#include "ssc_sip.h"
#include "ssc_oper.h"
#include "ssc_media.h"

#include <sofia-sip/sip.h>
#include <sofia-sip/sip_header.h>
#include <sofia-sip/sip_status.h>
#include <sofia-sip/nua.h>
#include <sofia-sip/nua_tag.h>
#include <sofia-sip/soa.h>
#include <sofia-sip/su_tag_io.h>
#include <sofia-sip/su_tagarg.h>
#include <sofia-sip/sl_utils.h>
#include <sofia-sip/su_debug.h>

typedef void (*ssc_exit_cb)(void);
typedef void (*ssc_event_cb)(ssc_t *ssc, nua_event_t event, void *context);
typedef void (*ssc_registration_cb)(ssc_t *ssc, int registered, void *context);
typedef void (*ssc_auth_req_cb)(ssc_t *ssc, const ssc_auth_item_t *authitem, void *context);
typedef void (*ssc_call_state_cb)(ssc_t *ssc, ssc_oper_t *oper, int ss_state, void *context);
typedef void (*ssc_media_state_cb)(ssc_t *ssc, ssc_oper_t *oper, enum SscMediaState state, void *context);

/**
 * Structure for storing pending authentication requests
 */
struct ssc_auth_item_s {
  char         *ssc_scheme;     /**< Scheme */
  char         *ssc_realm;      /**< Realm part */
  char         *ssc_username;   /**< Username part, if known */
  ssc_oper_t   *ssc_op;         /**< Operation this auth item is related to */
};

/**
 * Instance data for ssc_sip_t objects.
 */
struct ssc_s {
  su_home_t    *ssc_home;	/**< Our memory home */
  char const   *ssc_name;	/**< Our name */
  su_root_t    *ssc_root;       /**< Pointer to application root */

  nua_t        *ssc_nua;        /**< Pointer to NUA object */
  SscMedia     *ssc_media;      /**< Pointer to media subsystem */
  ssc_oper_t   *ssc_operations;	/**< Remote destinations */

  char         *ssc_address;    /**< Current AOR */

  int           ssc_autoanswer;

  GList        *ssc_auth_pend;  /**< Pending authentication requests (ssc_auth_item_t) */ 

  int           ssc_ans_status; /**< Answer status */
  char const   *ssc_ans_phrase; /**< Answer status */

  void         *ssc_cb_context; /**< Context for callbacks */
  ssc_exit_cb         ssc_exit_cb;        /**< Callback to signal stack shutdown */
  ssc_event_cb        ssc_event_cb;
  ssc_registration_cb ssc_registration_cb;
  ssc_call_state_cb   ssc_call_state_cb;
  ssc_media_state_cb  ssc_media_state_cb;
  ssc_auth_req_cb     ssc_auth_req_cb;
};

/** 
 * Configuration data for ssc_create().
 */
struct ssc_conf_s {
  const char   *ssc_aor;        /**< Public SIP address aka AOR (SIP URI) */
  const char   *ssc_certdir;	/**< Directory for TLS certs (directory path) */
  const char   *ssc_contact;	/**< SIP contact URI (local address to use) */
  const char   *ssc_media_addr;	/**< Media address (hostname, IP address) */
  const char   *ssc_media_impl;	/**< Media address (hostname, IP address) */
  const char   *ssc_proxy;	/**< SIP outbound proxy (SIP URI) */
  const char   *ssc_registrar;	/**< SIP registrar (SIP URI) */
  const char   *ssc_stun_server;/**< STUN server address (hostname, IP address) */
  gboolean      ssc_autoanswer; /**< Whether to autoanswer to calls */
  gboolean      ssc_register;	/**< Whether to register at startup */
};

#if HAVE_FUNC
#define enter (void)SU_DEBUG_9(("%s: entering\n", __func__))
#elif HAVE_FUNCTION
#define enter (void)SU_DEBUG_9(("%s: entering\n", __FUNCTION__))
#else
#define enter (void)0
#endif

ssc_t *ssc_create(su_home_t *home, su_root_t *root, const ssc_conf_t *conf);
void ssc_destroy(ssc_t *self);

void ssc_store_pending_auth(ssc_t *ssc, ssc_oper_t *op, sip_t const *sip, tagi_t *tags);

void ssc_answer(ssc_t *ssc, int status, char const *phrase);
void ssc_auth(ssc_t *ssc, const char *data);
void ssc_bye(ssc_t *ssc);
void ssc_cancel(ssc_t *ssc);
void ssc_hold(ssc_t *ssc, char *destination, int hold);
void ssc_info(ssc_t *ssc, const char *destination, const char *msg);
void ssc_invite(ssc_t *ssc, const char *destination);
void ssc_list(ssc_t *ssc);
void ssc_media_describe(ssc_t *ssc, char *rest);
void ssc_media_event(ssc_t *ssc, char *rest);
void ssc_message(ssc_t *ssc, const char *destination, const char *msg);
void ssc_options(ssc_t *ssc, char *destination);
void ssc_refer(ssc_t *ssc, const char *destination, const char *to_address);
void ssc_register(ssc_t *ssc, const char *registrar);
void ssc_unregister(ssc_t *ssc, const char *registrar);
void ssc_param(ssc_t *cli, char *param, char *s);
void ssc_publish(ssc_t *ssc, const char *note);
void ssc_unpublish(ssc_t *ssc);
void ssc_set_public_address(ssc_t *ssc, const char *aor);
void ssc_shutdown(ssc_t *ssc);
void ssc_subscribe(ssc_t *ssc, char *destination);
void ssc_unsubscribe(ssc_t *ssc, char *destination);
void ssc_watch(ssc_t *ssc, char *event);
void ssc_zap(ssc_t *ssc, char *d);

void ssc_print_payload(ssc_t *ssc, sip_payload_t const *pl);
void ssc_print_settings(ssc_t *ssc);

#endif /* HAVE_SSC_SIP_H */
