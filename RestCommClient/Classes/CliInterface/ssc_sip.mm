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

/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2015, Telestax Inc and individual contributors
 * by the @authors tag.
 *
 * This program is free software: you can redistribute it and/or modify
 * under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 * For questions related to commercial use licensing, please contact sales@telestax.com.
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

#import <vector>

#include <stddef.h>
#include <stdlib.h>
#include <string>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <sofia-sip/stun_tag.h>

#include "ssc_media_simple.h"
#include "ssc_sip.h"
#include "ssc_oper.h"
#include "common.h"
#include "RCUtilities.h"

/* Globals
 * ------------------- */
static struct SofiaReply sofiaReply;
// Indication of whether sofia stack is currently shutting down. This is needed for the edge scenario
// where the user leaves and re-enters the App very quickly and the previous shutdown doesn't have time
// to complete until the App is reopened and from then on stays disconnected and not able to handle requests.
//
// With this global var we keep whether we are currently shutting down and if so if a new stack is requested
// we mark it so that it is restarted after the previous stack is shutdown
bool stackIsShuttingDown = false;


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
static void priv_media_state_cb(void* context, int state, void * data);
static void priv_destroy_oper_with_disconnect (ssc_t *self, ssc_oper_t *oper);

/* Function definitions
 * -------------------- */

ssc_t *ssc_create(su_home_t *home, su_root_t *root, const ssc_conf_t *conf, const int input_fd, const int output_fd)
{
    ssc_t *ssc;
    string caps_str;
    char *userdomain = NULL;
    string contact = "", secure_contact = "";
    const char *proxy = NULL, *registrar = NULL, *cert_dir = NULL;
    stackIsShuttingDown = false;
    
    ssc = (ssc_t *)su_zalloc(home, sizeof(*ssc));

    if (!ssc)
        return ssc;
    
    ssc->ssc_auth_pend = new std::list<ssc_auth_item_t*>;
    ssc->ssc_input_fd = input_fd;
    ssc->ssc_output_fd = output_fd;
    
    ssc->ssc_name = "UA";
    ssc->ssc_home = home;
    ssc->ssc_root = root;
    
    
    /* step: create media subsystem instance */
    ssc->ssc_media = new SscMediaSimple();
    assert(ssc->ssc_media);
    /* step: query capabilities of the media subsystem */
    caps_str = ssc->ssc_media->ssc_media_static_capabilities();
    
    /* step: find out the home domain of the account */
    if (conf->ssc_aor)
        userdomain = priv_parse_domain(home, conf->ssc_aor);
    
    ssc->ssc_address = su_strdup(home, conf->ssc_aor);
    ssc->ssc_autoanswer = conf->ssc_autoanswer;
    
    NSString * address = [RCUtilities getPrimaryIPAddress];
    if ([address isEqualToString:@""]) {
        int outputFd = ssc->ssc_output_fd;
        RCLogError("No valid interface to bind to with nua_create()");
        ssc_destroy(ssc);
        ssc = NULL;
        su_free(home, userdomain);

        SofiaReply reply(ERROR_SIP_INITIALIZING_SIGNALING, "Error initializing signaling: no valid network interface to bind to");
        reply.Send(outputFd);

        return ssc;
    }
    
    // NULL unless there's actual text in ssc_proxy, so that TAG_IF below works
    if (conf->ssc_proxy && strcmp(conf->ssc_proxy, "")) {
        proxy = conf->ssc_proxy;
    }
    if (conf->ssc_registrar && strcmp(conf->ssc_registrar, "")) {
        registrar = conf->ssc_registrar;
    }
    if (conf->ssc_certdir && strcmp(conf->ssc_certdir, "")) {
        cert_dir = conf->ssc_certdir;
    }
    
    /* note: by default bind to a random port on all interfaces */
    if (conf->ssc_contact) {
        contact = conf->ssc_contact;
    }
    else {
        /*
        contact = "sip:";
        contact += [address UTF8String];
        contact += ":*;transport=tcp";
        //contact +=  ":5090;transport=tcp";
         */

        if (cert_dir) {
            secure_contact = "sips:";
            secure_contact += [address UTF8String];
            secure_contact += ":*;transport=tls";
            //secure_contact +=  ":5091;transport=tls";
        }
        else {
            contact = "sip:";
            contact += [address UTF8String];
            contact += ":*;transport=tcp";
            //contact +=  ":5090;transport=tcp";
        }
    }

    RCLogNotice("Creating SIP stack -binding to: %s, cert dir: %s", contact.c_str(), cert_dir);

    /* step: launch the SIP stack */
    ssc->ssc_nua = nua_create(root,
                              priv_callback, ssc,
                              TAG_IF(conf->ssc_aor,
                                     SIPTAG_FROM_STR(conf->ssc_aor)),

                              // timeout timer (SIP B Timer which defaults to 32 secs)
                              NTATAG_SIP_T1X64(8000),
                              
                              TAG_IF(proxy,
                                     NUTAG_PROXY(proxy)),
                              TAG_IF(registrar,
                                     NUTAG_REGISTRAR(registrar)),
                              
                              TAG_IF(!contact.empty(),
                                     NUTAG_URL(contact.c_str())),
                              
                              TAG_IF(!secure_contact.empty(),
                                     NUTAG_SIPS_URL(secure_contact.c_str())),
                              TAG_IF(cert_dir,
                                     NUTAG_CERTIFICATE_DIR(cert_dir)),

                              //NUTAG_M_PARAMS("transport=tcp"),
                              TAG_IF(conf->ssc_media_addr,
                                     NUTAG_MEDIA_ADDRESS(conf->ssc_media_addr)),
                              // note: use of STUN for signaling disabled
                              //TAG_IF(conf->ssc_stun_server, STUNTAG_SERVER(conf->ssc_stun_server)),
                              //TAG_IF(userdomain, STUNTAG_DOMAIN(userdomain)),
                              
                              /* Used in OPTIONS */
                              TAG_IF(caps_str.c_str(),
                                     SOATAG_USER_SDP_STR(caps_str.c_str())),
                              SOATAG_AF(SOA_AF_IP4_IP6),
                              // When using webrtc media disable SOA engine for SDP handling
                              NUTAG_MEDIA_ENABLE(0),
                              // doesn't seem to work
                              //NUTAG_DETECT_NETWORK_UPDATES(NUA_NW_DETECT_TRY_FULL),
                              SIPTAG_USER_AGENT_STR(SIP_USER_AGENT),
                              TAG_NULL());
    
    if (conf->ssc_register)
        ssc_register(ssc, conf->ssc_registrar, conf->ssc_password);
    
    if (ssc->ssc_nua) {
        nua_set_params(ssc->ssc_nua,
                       NUTAG_ENABLEMESSAGE(1),
                       NUTAG_ENABLEINVITE(1),
                       NUTAG_AUTOALERT(1),
                       NUTAG_SESSION_TIMER(0),
                       NUTAG_AUTOANSWER(0),
                       //NUTAG_OUTBOUND("use-rport"),
                       //TAG_IF("64.233.184.127", STUNTAG_SERVER("64.233.184.127")),
                       //TAG_IF("stun.l.google.com", STUNTAG_DOMAIN("stun.l.google.com")),
                       //TAG_IF(cert_dir,
                       //       NUTAG_CERTIFICATE_DIR(cert_dir)),
                       TAG_NULL());
        //nua_get_params(ssc->ssc_nua, TAG_ANY(), TAG_NULL());
        SofiaReply reply(SIGNALLING_INITIALIZED, "");
        reply.Send(ssc->ssc_output_fd);
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
    ssc_oper_destroy(self, op);
}

void ssc_destroy(ssc_t *self)
{
    su_home_t *home = self->ssc_home;
 
    // remember that ssc_auth_pend is now an stl list allocated with new; need to delete
    if (self->ssc_auth_pend) {
        delete self->ssc_auth_pend;
    }
    
    if (self->ssc_media) {
        //g_object_unref(self->ssc_media), self->ssc_media = NULL;
        delete self->ssc_media;
        //ssc_media_finalize(self->ssc_media);
        self->ssc_media = NULL;
    }
    if (self->ssc_address)
        su_free(home, self->ssc_address);
    
    su_free(home, self);
}

static ssc_auth_item_t *priv_store_pending_auth(su_home_t *home, const char *scheme, msg_param_t const *au_params)
{
    const char *realm = msg_params_find(au_params, "realm=");
    ssc_auth_item_t *authitem = (ssc_auth_item_t*)su_zalloc(home, sizeof(*authitem));
    
    if (authitem) {
        authitem->ssc_scheme = su_strdup(home, scheme);
        if (realm)
            authitem->ssc_realm = su_strdup(home, realm);
    }
    
    return authitem;
}

void priv_attach_op_and_username(ssc_t *self, ssc_auth_item_t *authitem, sip_from_t const *sipfrom, su_home_t *home, ssc_oper_t *op)
{
    authitem->ssc_op = op;
    
    //if (sipfrom && sipfrom->a_url)
    if (sipfrom)
        authitem->ssc_username = su_strdup(home, sipfrom->a_url->url_user);
    
    /* XXX: should check for already existing entries for the realm */
    nua_handle_ref(op->op_handle);
    
    self->ssc_auth_pend->push_back(authitem);
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
    
    //RCLogDebug("%s: %s was unauthorized", self->ssc_name, op->op_method_name);
    
    if (wa) {
        // TODO:
        //sl_header_print(stdout, "Server auth: %s\n", (sip_header_t *)wa);
        authitem = priv_store_pending_auth(home, wa->au_scheme, wa->au_params);
        priv_attach_op_and_username(self, authitem, sipfrom, home, op);
    }
    
    if (pa) {
        // TODO
        //sl_header_print(stdout, "Proxy auth: %s\n", (sip_header_t *)pa);
        authitem = priv_store_pending_auth(home, pa->au_scheme, pa->au_params);
        priv_attach_op_and_username(self, authitem, sipfrom, home, op);
    }
    
    if (authitem) {
        if (self->ssc_auth_req_cb)
            self->ssc_auth_req_cb (self, authitem, self->ssc_cb_context);
    }
    
    if (op->password) {
        ssc_auth(self, op->password);
    }
    else {
        RCLogError("Error: operation password is NULL during authentication, bailing");
    }
    
    // notify the client application that they should provide credentials
    //SofiaReply reply(REPLY_AUTH, "auth");
    //reply.Send(self->ssc_output_fd);
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
    if (!ssc) {
        RCLogDebug("Error: ssc NULL in priv_callback");
        return;
    }

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
        /* doesn't seem to work
        case nua_i_network_changed:
            RCLogDebug("%s: Network changed event: '%s' (%d): %03d %s",
                         ssc->ssc_name, nua_event_name(event), event, status, phrase);
            break;
         */
        case nua_i_active:
        case nua_i_ack:
        case nua_i_terminated:
        case nua_r_set_params:
            break;
            
        default:
            if (status > 100)
                RCLogDebug("Unhandled event '%s' (%d): %03d %s", nua_event_name(event), event, status, phrase);
            else
                RCLogDebug("Unhandled event %d", event);
#if DEBUG_SOFIA
            tl_print(stdout, "", tags);
#endif
            
            if (ssc_oper_find_by_handle(ssc, nh) == NULL) {
                /* note: unknown handle, not associated to any existing
                 *       call, message, registration, etc, so it can
                 *       be safely destroyed */
                RCLogDebug("Unknown handle %p. Destroying it", nh);
                nua_handle_destroy(nh);
            }
            
            break;
            
    }
    
    if (ssc->ssc_event_cb)
        ssc->ssc_event_cb ((ssc_t *)ssc, event, ssc->ssc_cb_context);
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
    std::list<ssc_auth_item_t*>::const_iterator it = ssc->ssc_auth_pend->begin();
    ssc_auth_item_t *authitem;
    int auth_done = 0, colons = priv_str_chr_count(data, ':');
    
    while (it != ssc->ssc_auth_pend->end() && auth_done == 0) {
        
        authitem = (ssc_auth_item_t*)*it;
        
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
            
            RCLogDebug("Authenticating '%s'", authitem->ssc_op->op_method_name);
            
            /* XXX: if realm does not match, nua does not notify client about
             *      the mismatch in any way */
            nua_authenticate(authitem->ssc_op->op_handle, NUTAG_AUTH(authstring), TAG_END());
            
            auth_done = 1;
            
            if (tmpstr)
                su_free(home, tmpstr);
            
            nua_handle_unref(authitem->ssc_op->op_handle);
        }
        else {
            RCLogDebug("Stale authentication challenge '%s', ignoring.", ssc->ssc_name, authitem->ssc_realm);
        }
        
        /* remove the pending auth item list->data */
        su_free(home, authitem->ssc_scheme);
        su_free(home, authitem->ssc_realm);
        su_free(home, authitem->ssc_username);
        su_free(home, authitem);
        
        it = ssc->ssc_auth_pend->erase(it);
    }
    
    if (auth_done == 0)
        RCLogDebug("%s: No operation to authenticate", ssc->ssc_name);
}


/**
 * Prints verbose error information to stdout.
 */
void ssc_i_error(nua_t *nua, ssc_t *ssc, nua_handle_t *nh, ssc_oper_t *op,
                 int status, char const *phrase,
                 tagi_t tags[])
{
    RCLogDebug("Error %03d %s", status, phrase);
}

/**
 * Lists all active operations to stdout.
 */
void ssc_list(ssc_t *ssc)
{
    ssc_oper_t *op;
    
    RCLogDebug("%s: listing active handles", ssc->ssc_name);
    for (op = ssc->ssc_operations; op; op = op->op_next) {
        if (op->op_ident) {
            RCLogDebug("\t%s to %s",
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
void ssc_invite(ssc_t *ssc, const char *destination, const char *password, const char * sdp, const char *headers)
{
    /* enable this to not allow second outgoing call on top of the first
    int check_states = opc_pending | opc_complete | opc_sent | opc_active;
    if (ssc_oper_find_by_callstate(ssc, check_states)) {
        RCLogDebug("There's a call already in progress, ignoring new request");
        return;
    }
     */

    ssc_oper_t *op = ssc_oper_create_with_password(ssc, SIP_METHOD_INVITE, destination, password, TAG_END());
    if (op) {
        /* SDP O/A note:
         *  - before issuing nua_invite(), we activate the media
         *    subsystem (allocates network and  media device resources)
         *  - once the media subsystem is ready, we get a callback
         *  - see also: ssc_i_state(), priv_media_state_cb(), and ssc_answer()
         */
        
        //op->op_callstate |= opc_pending;
        op->op_callstate = (op_callstate_t)(op->op_callstate | opc_pending);
        op->is_outgoing = true;
        op->custom_headers = su_strdup(ssc->ssc_home, headers);

        // set localsdp with WebRTC media
        ssc->ssc_media->setLocalSdp(sdp);
        
        /* active media before INVITE */
        int res = ssc->ssc_media->ssc_media_activate();
        
        if (res < 0) {
            RCLogDebug("%s: ERROR: unable to active media subsystem, aborting session.", ssc->ssc_name);
            priv_destroy_oper_with_disconnect (ssc, op);
        }
        else {
            RCLogDebug("%s: INVITE to %s pending", ssc->ssc_name, op->op_ident);
        }
        
        priv_media_state_cb(ssc->ssc_media, ssc->ssc_media->sm_state, op);
    }
    else {
        SofiaReply reply(ERROR_SIP_INVITE_SIP_URI_INVALID, [[RestCommClient getErrorText:ERROR_SIP_INVITE_SIP_URI_INVALID] UTF8String]);
        reply.Send(ssc->ssc_output_fd);
    }
}

/**
 * Callback that triggers the second phase of
 * ssc_invite() for WebRTC. When WebRTC module is ready with full SDP
 * (including ICE candidates), it calls this via the pipe interface to 
 * set the local sdp and activate media
 */
void ssc_webrtc_sdp(void* op_context, char *sdp)
{
    ssc_oper_t *op = (ssc_oper_t*)op_context;
    ssc_t *ssc = op->op_ssc;
    int res;
    
    // set localsdp with WebRTC media
    ssc->ssc_media->setLocalSdp(sdp);
    
    /* active media before INVITE */
    res = ssc->ssc_media->ssc_media_activate();
    
    if (res < 0) {
        RCLogDebug("%s: ERROR: unable to active media subsystem, aborting session.", ssc->ssc_name);
        priv_destroy_oper_with_disconnect (ssc, op);
    }
    else {
        RCLogDebug("%s: INVITE to %s pending", ssc->ssc_name, op->op_ident);
    }
    
    priv_media_state_cb(ssc->ssc_media, ssc->ssc_media->sm_state, op);
}

/**
 * Callback for an outgoing INVITE request.
 */
void ssc_r_invite(int status, char const *phrase,
                  nua_t *nua, ssc_t *ssc,
                  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                  tagi_t tags[])
{
    RCLogNotice("%s: INVITE: %03d %s", ssc->ssc_name, status, phrase);
    
    if (status >= 300) {
        op->op_callstate = (op_callstate_t)(op->op_callstate & ~opc_sent);
        if (status == 401 || status == 407) {
            ssc_store_pending_auth(ssc, op, sip, tags);
        }
        else if (status == 486 || status == 600 || status == 603) {
            // notify the client application that we are ringing
            SofiaReply reply(OUTGOING_DECLINED, "");
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 487) {
            // notify the client application that we got a response to our CANCEL
            SofiaReply reply(OUTGOING_CANCELLED, "");
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 404) {
            // not found
            SofiaReply reply(ERROR_SIP_INVITE_NOT_FOUND, [[RestCommClient getErrorText:ERROR_SIP_INVITE_NOT_FOUND] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 403) {
            // authentication error
            SofiaReply reply(ERROR_SIP_INVITE_AUTHENTICATION, [[RestCommClient getErrorText:ERROR_SIP_INVITE_AUTHENTICATION] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 408) {
            // timeout error
            SofiaReply reply(ERROR_SIP_INVITE_TIMEOUT, [[RestCommClient getErrorText:ERROR_SIP_INVITE_TIMEOUT] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 503) {
            // timeout error
            SofiaReply reply(ERROR_SIP_INVITE_SERVICE_UNAVAILABLE, [[RestCommClient getErrorText:ERROR_SIP_INVITE_SERVICE_UNAVAILABLE] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else {
            // generic error
            RCLogError("INVITE Unknown error: %03d %s", status, phrase);
            SofiaReply reply(ERROR_SIP_INVITE_GENERIC, [[RestCommClient getErrorText:ERROR_SIP_INVITE_GENERIC] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
    }
    if (status == 180) {
        // notify the client application that we are ringing
        SofiaReply reply(OUTGOING_RINGING, "");
        reply.Send(ssc->ssc_output_fd);
        //setSofiaReply(OUTGOING_RINGING, "");
        //sendSofiaReply(ssc->ssc_output_fd, &sofiaReply);
    }
    if (status == 200) {
        // notify the client application that we are established
        SofiaReply reply(OUTGOING_ESTABLISHED, sip->sip_payload->pl_data);
        reply.Send(ssc->ssc_output_fd);
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
    
    RCLogDebug("%s: call fork: %03d %s", ssc->ssc_name, status, phrase);
    
    /* We just release forked calls. */
    tl_gets(tags, NUTAG_HANDLE_REF(nh2), TAG_END());
    if (!nh2) {
        RCLogDebug("Error: nh2 NULL in ssc_i_fork");
        return;
    }
    
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
    
    if (!sip) {
        RCLogDebug("Error: sip is NULL in ssc_i_invite");
        return;
    }
    
    /*
    char const *s_contact = NULL;

    tl_gets(tags,
            SIPTAG_CONTACT_STR_REF(s_contact),
            TAG_END());
     */
    
    from = sip->sip_from;
    to = sip->sip_to;
    subject = sip->sip_subject;
    //sip_contact_t const *contact = sip->sip_contact;
    //sip_contact_t * contact = sip_contact_make(ssc->ssc_home, "sip:alice@54.225.212.193:5080;transport=udp");
    //url_t * url = url_make(ssc->ssc_home, "sip:alice@54.225.212.193:5080;transport=udp");
    //sip->sip_contact->m_url = url;
    
    if (!(from && to)) {
        RCLogDebug("Error: sip is NULL in ssc_i_invite");
        return;
    }
    
    if (op) {
        op->op_callstate = (op_callstate_t)(op->op_callstate | opc_recv);
        op->is_outgoing = false;
    }
    else if ((op = ssc_oper_create_with_handle(ssc, SIP_METHOD_INVITE, nh, from))) {
        op->op_callstate = opc_recv;
        op->is_outgoing = false;
    }
    else {
        nua_respond(nh, SIP_500_INTERNAL_SERVER_ERROR, TAG_END());
        nua_handle_destroy(nh);
    }
    
    if (op) {
        if (op->op_callstate == opc_recv) {
            RCLogDebug("%s: incoming call\n\tFrom: %s", ssc->ssc_name, op->op_ident);
            RCLogDebug("\tTo: %s%s<" URL_PRINT_FORMAT ">",
                   to->a_display ? to->a_display : "",
                   to->a_display ? " " : "",
                   URL_PRINT_ARGS(to->a_url));
            if (subject)
                RCLogDebug("\tSubject: %s", subject->g_value);
            
            if (ssc->ssc_autoanswer) {
                ssc_answer(ssc, NULL, SIP_200_OK);
            }
            else {
                RCLogDebug("Please Answer(a), decline(d) or Decline(D) the call");

                char url[1000];
                snprintf(url, sizeof(url), URL_PRINT_FORMAT, URL_PRINT_ARGS(from->a_url));
                
                NSDictionary * message = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:url], @"sip-uri",
                                          [NSString stringWithUTF8String:sip->sip_payload->pl_data], @"sdp", nil];

                // notify the client application that they should answer
                SofiaReply reply(INCOMING_CALL, [[RCUtilities stringifyDictionary:message] UTF8String]);
                reply.Send(ssc->ssc_output_fd);
            }
        }
        else {
            RCLogDebug("%s: re-INVITE from: %s", ssc->ssc_name, op->op_ident);
        }
    }
}

/**
 * Callback that triggers the second (or third if WebRTC is involved) 
 * phase of ssc_answer() and ssc_invite(). Verifies that the media subsystem has
 * been activated and we are ready to answer with our SDP.
 */
static void priv_media_state_cb(void* context, int state, void * data)
{
    ssc_oper_t *op = (ssc_oper_t*)data;
    ssc_t *ssc = op->op_ssc;
    
    //g_debug ("%s, state %u", G_STRFUNC, state);
    
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
            ssc->ssc_media->ssc_media_is_initialized()) {
            string l_sdp = "";
            
            op->op_callstate = (op_callstate_t)(op->op_callstate & !opc_pending);
            
            /* get the ports and list of media */
            l_sdp = ssc->ssc_media->getLocalSdp();
            
            if (!l_sdp.empty()) {
                //RCLogDebug("%s: about to make a call with local SDP:\n%s", ssc->ssc_name, l_sdp.c_str());
                
                // When working with webrtc media using the SOA ruins the SDP for some reason.
                // Since webrtc handles the SDP completely, let's disable SOA
                // (see nua_create, NUTAG_MEDIA_ENABLE(0)) and use the webrtc string directy with
                // SIPTAG_PAYLOAD_STR() and SIPTAG_CONTENT_TYPE_STR()
                nua_invite(op->op_handle,
                           TAG_IF(op->custom_headers, SIPTAG_HEADER_STR(op->custom_headers)),
                           SIPTAG_PAYLOAD_STR(l_sdp.c_str()),
                           SIPTAG_CONTENT_TYPE_STR("application/sdp"),
                           SOATAG_RTP_SORT(SOA_RTP_SORT_REMOTE),
                           SOATAG_RTP_SELECT(SOA_RTP_SELECT_ALL),
                           TAG_END());
                
                op->op_callstate = (op_callstate_t)(op->op_callstate | opc_sent);
                RCLogDebug("%s: INVITE to %s", ssc->ssc_name, op->op_ident);
            }
            else {
                op->op_callstate = (op_callstate_t)(op->op_callstate | opc_none);

                printf("ERROR: no SDP provided by media subsystem, aborting call.");
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
            string l_sdp_str = "";
            int status = ssc->ssc_ans_status;
            char const *phrase = ssc->ssc_ans_phrase;
            
            /* get the ports and list of media */
            l_sdp_str = ssc->ssc_media->getLocalSdp();
            
            RCLogDebug("%s: about to respond with local SDP:\n%s",
                   ssc->ssc_name, l_sdp_str.c_str());
            
            if (!l_sdp_str.empty()) {
                if (status >= 200 && status < 300) {
                    op->op_callstate = (op_callstate_t)(op->op_callstate | opc_sent);
                }
                else
                    op->op_callstate = opc_none;
                // When working with webrtc media using the SOA ruins the SDP for some reason.
                // Since webrtc handles the SDP completely, let's disable SOA
                // (see nua_create, NUTAG_MEDIA_ENABLE(0)) and use the webrtc string directy with
                // SIPTAG_PAYLOAD_STR() and SIPTAG_CONTENT_TYPE_STR()
                nua_respond(op->op_handle, status, phrase,
                            //SOATAG_USER_SDP_STR(l_sdp_str),
                            SIPTAG_PAYLOAD_STR(l_sdp_str.c_str()),
                            SIPTAG_CONTENT_TYPE_STR("application/sdp"),
                            SOATAG_RTP_SORT(SOA_RTP_SORT_REMOTE),
                            SOATAG_RTP_SELECT(SOA_RTP_SELECT_ALL),
                            TAG_END());
                
                // TODO: remove when done debugging
                //nua_get_hparams(op->op_handle, TAG_ANY(), TAG_NULL());
                //nua_get_params(nua, TAG_ANY(), TAG_NULL());

            }
            else {
                RCLogDebug("ERROR: no SDP provided by media subsystem, unable to answer call.");
                op->op_callstate = opc_none;
                nua_respond(op->op_handle, 500, "Not Acceptable Here", TAG_END());
            }
        }
    }
    else if (state == sm_error) {
        RCLogDebug("%s: Media subsystem reported an error.", ssc->ssc_name);
        ssc->ssc_media->ssc_media_deactivate();
        priv_destroy_oper_with_disconnect (ssc, op);
    }
    
    // TODO: check if this removal causes us any issues
    //if (ssc->ssc_media_state_cb)
    //    ssc->ssc_media_state_cb (ssc, op, (enum SscMediaState)state, ssc->ssc_cb_context);
    
}

/**
 * Answers a call (processed in two phases).
 *
 * See also ssc_i_invite().
 */
void ssc_answer(ssc_t *ssc, char * sdp, int status, char const *phrase)
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
        
        /* active media before sending offer */
        if (status >= 200 && status < 300) {
            // set localsdp with WebRTC media
            if (sdp) {
                ssc->ssc_media->setLocalSdp(sdp);
            }
            
            int res = ssc->ssc_media->ssc_media_activate();
            if (res < 0) {
                RCLogDebug("%s: ERROR: unable to active media subsystem, unable to answer session.", ssc->ssc_name);
                priv_destroy_oper_with_disconnect (ssc, op);
                // ssc_oper_destroy(ssc, op);
            }
            else {
                RCLogDebug("%s: answering to the offer received from %s", ssc->ssc_name, op->op_ident);
            }
            priv_media_state_cb(ssc->ssc_media, ssc->ssc_media->sm_state, op);
        }
        else {
            /* call rejected */
            nua_respond(op->op_handle, status, phrase, TAG_END());
            priv_destroy_oper_with_disconnect (ssc, op);
        }
        
    }
    else
        RCLogDebug("%s: no call to answer", ssc->ssc_name);
}

/**
 * Callback that triggers the second phase of ssc_answer()
 * for WebRTC. When WebRTC module is ready with full SDP
 * (including ICE candidates), it calls this via the pipe interface
 * to set the localsdp
 */
void ssc_webrtc_sdp_called(void* op_context, char *sdp)
{
    ssc_oper_t *op = (ssc_oper_t*)op_context;
    ssc_t *ssc = op->op_ssc;
    
    // set localsdp with WebRTC media
    ssc->ssc_media->setLocalSdp(sdp);
    
    int res = ssc->ssc_media->ssc_media_activate();
    if (res < 0) {
        RCLogDebug("%s: ERROR: unable to active media subsystem, unable to answer session.", ssc->ssc_name);
        priv_destroy_oper_with_disconnect (ssc, op);
        // ssc_oper_destroy(ssc, op);
    }
    else {
        RCLogDebug("%s: answering to the offer received from %s", ssc->ssc_name, op->op_ident);
    }
    priv_media_state_cb(ssc->ssc_media, ssc->ssc_media->sm_state, op);
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
    
    if (!sip) {
        RCLogDebug("Error: sip is NULL for ssc_i_prack");
        return;
    }
    
    rack = sip->sip_rack;
    
    RCLogDebug("%s: received PRACK %u", ssc->ssc_name, rack ? rack->ra_response : 0);
    
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
    
    if (!op) {
        RCLogDebug("Error: op is NULL for ssc_i_state");
        return;
    }
    
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
        if (!(answer_sent || offer_sent)) {
            RCLogDebug("Error: bad state in ssc_i_state");
            return;
        }
        ssc->ssc_media->setLocalSdp(l_sdp);
        /* RCLogDebug("%s: local SDP updated:\n%s", ssc->ssc_name, l_sdp); */
    }
    
    if (r_sdp) {
        if (!(answer_sent || offer_sent)) {
            RCLogDebug("Error: bad state in ssc_i_state");
            return;
        }
        ssc->ssc_media->setRemoteSdp(r_sdp);
        /* RCLogDebug("%s: remote SDP updated:\n%s", ssc->ssc_name, r_sdp); */
    }
    
    switch ((enum nua_callstate)ss_state) {
            
        case nua_callstate_calling:
            // mark outgoing
            break;
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
                RCLogDebug("%s: call to %s is active => '%s'\n\taudio %s, video %s, chat %s.",
                       ssc->ssc_name, op->op_ident, nua_callstate_name((enum nua_callstate)ss_state),
                       cli_active(audio), cli_active(video), cli_active(chat));
                op->op_prev_state = ss_state;
                
                if (!op->is_outgoing) {
                   SofiaReply reply(INCOMING_ESTABLISHED, "");
                   reply.Send(ssc->ssc_output_fd);
                }
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
                RCLogDebug("%s: call to %s is terminated", ssc->ssc_name, op->op_ident);
                op->op_callstate = (op_callstate_t)0;
                priv_destroy_oper_with_disconnect (ssc, op);
                /* SDP O/A note:
                 * - de-active media subsystem */
                if (ssc->ssc_media->ssc_media_is_initialized() == true)
                    ssc->ssc_media->ssc_media_deactivate();
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
    //sip_to_t * to = sip_to_make(ssc->ssc_home, "sip:alice@54.225.212.193:5080");
    
    if (op) {
        /*
        nua_set_hparams(op->op_handle,
                        //SIPTAG_REQUEST_STR("BYE sip:alice@54.225.212.193:5080 SIP/2.0"),
                        TAG_NULL());
         */
        RCLogDebug("%s: BYE to %s", ssc->ssc_name, op->op_ident);
        nua_bye(op->op_handle,
                //SIPTAG_REQUEST_STR("BYE sip:alice@54.225.212.193:5080 SIP/2.0"),
                //NUTAG_URL(to->a_url),  // doesn't change anything
                //SIPTAG_TO(sip_to_make(ssc->ssc_home, "sip:alice@54.225.212.193:5080")),
                TAG_END());
        op->op_callstate = (op_callstate_t)0;
    }
    else {
        RCLogDebug("%s: no call to bye", ssc->ssc_name);
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
    
    RCLogDebug("%s: BYE: %03d %s", ssc->ssc_name, status, phrase);
    if (status < 200)
        return;

    SofiaReply reply(OUTGOING_BYE_RESPONSE, "");
    reply.Send(ssc->ssc_output_fd);
    //setSofiaReply(OUTGOING_BYE_RESPONSE, "");
    //sendSofiaReply(ssc->ssc_output_fd, &sofiaReply);
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
    
    RCLogDebug("%s: BYE received", ssc->ssc_name);

    SofiaReply reply(INCOMING_BYE, "");
    reply.Send(ssc->ssc_output_fd);
    //setSofiaReply(INCOMING_BYE, "");
    //sendSofiaReply(ssc->ssc_output_fd, &sofiaReply);
}

/**
 * Cancels a call operation currently in progress (if any).
 */
void ssc_cancel(ssc_t *ssc)
{
    ssc_oper_t *op = ssc_oper_find_call_in_progress(ssc);
    
    if (op) {
#ifdef DEBUG
        RCLogDebug("%s: CANCEL %s to %s",
               ssc->ssc_name, op->op_method_name, op->op_ident);
#endif
        nua_cancel(op->op_handle, TAG_END());
    }
    else if ((op = ssc_oper_find_call_embryonic(ssc))) {
        RCLogDebug("%s: reject REFER to %s",
               ssc->ssc_name, op->op_ident);
        nua_cancel(op->op_handle, TAG_END());
    }
    else {
        RCLogDebug("%s: no call to CANCEL", ssc->ssc_name);
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
    
    RCLogDebug("%s: CANCEL received", ssc->ssc_name);
    
    SofiaReply reply(INCOMING_CANCELLED, "");
    reply.Send(ssc->ssc_output_fd);
    //setSofiaReply(INCOMING_CANCELLED, "");
    //sendSofiaReply(ssc->ssc_output_fd, &sofiaReply);
}

void ssc_zap(ssc_t *ssc, char *which)
{
    ssc_oper_t *op;
    
    op = ssc_oper_create(ssc, sip_method_unknown, NULL, NULL, TAG_END());
    
    if (op) {
        RCLogDebug("%s: zap %s to %s", ssc->ssc_name,
               op->op_method_name, op->op_ident);
        priv_destroy_oper_with_disconnect (ssc, op);
    }
    else
        RCLogDebug("No operations to zap");
}

/**
 * Sends an option request to 'destionation'.
 */
void ssc_options(ssc_t *ssc, char *destination)
{
    ssc_oper_t *op = ssc_oper_create(ssc, SIP_METHOD_OPTIONS, destination,
                                     TAG_END());
    
    if (op) {
        RCLogDebug("%s: OPTIONS to %s", ssc->ssc_name, op->op_ident);
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
    RCLogDebug("%s: OPTIONS received", ssc->ssc_name);
}

/**
 * Callback to an outgoing OPTIONS request.
 */
void ssc_r_options(int status, char const *phrase,
                   nua_t *nua, ssc_t *ssc,
                   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                   tagi_t tags[])
{
    RCLogDebug("%s: OPTIONS %d %s", ssc->ssc_name, status, phrase);
    
    if (status == 401 || status == 407)
        ssc_store_pending_auth(ssc, op, sip, tags);
}

void ssc_message(ssc_t *ssc, const char *destination, const char *password, const char *msg, const char * headers)
{
    ssc_oper_t *op = ssc_oper_create_with_password(ssc, SIP_METHOD_MESSAGE, destination, password,
                                     TAG_END());
    
    if (op) {
        
        RCLogDebug("%s: sending message to %s", ssc->ssc_name, op->op_ident);
        
        nua_message(op->op_handle,
                    TAG_IF(headers, SIPTAG_HEADER_STR(headers)),
                    SIPTAG_CONTENT_TYPE_STR("text/plain"),
                    SIPTAG_PAYLOAD_STR(msg),
                    TAG_END());
    }
    else {
        SofiaReply reply(ERROR_SIP_MESSAGE_URI_INVALID, [[RestCommClient getErrorText:ERROR_SIP_MESSAGE_URI_INVALID] UTF8String]);
    }
}

void ssc_r_message(int status, char const *phrase,
                   nua_t *nua, ssc_t *ssc,
                   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                   tagi_t tags[])
{
    RCLogDebug("%s: MESSAGE: %d %s", ssc->ssc_name, status, phrase);
    
    if (status < 200) {
        return;
    }
    else if (status == 200) {
        return;
    }
    else if (status == 401 || status == 407) {
        ssc_store_pending_auth(ssc, op, sip, tags);
    }
    else if (status == 404) {
        SofiaReply reply(ERROR_SIP_MESSAGE_NOT_FOUND, [[RestCommClient getErrorText:ERROR_SIP_MESSAGE_NOT_FOUND] UTF8String]);
        reply.Send(ssc->ssc_output_fd);
    }
    else if (status == 403) {
        // authentication error
        SofiaReply reply(ERROR_SIP_MESSAGE_AUTHENTICATION, [[RestCommClient getErrorText:ERROR_SIP_MESSAGE_AUTHENTICATION] UTF8String]);
        reply.Send(ssc->ssc_output_fd);
    }
    else if (status == 408) {
        // timeout error
        SofiaReply reply(ERROR_SIP_MESSAGE_TIMEOUT, [[RestCommClient getErrorText:ERROR_SIP_MESSAGE_TIMEOUT] UTF8String]);
        reply.Send(ssc->ssc_output_fd);
    }
    else if (status == 503) {
        // timeout error
        SofiaReply reply(ERROR_SIP_MESSAGE_SERVICE_UNAVAILABLE, [[RestCommClient getErrorText:ERROR_SIP_MESSAGE_SERVICE_UNAVAILABLE] UTF8String]);
        reply.Send(ssc->ssc_output_fd);
    }
    else {
        RCLogError("MESSAGE Unknown error: %03d %s", status, phrase);
        SofiaReply reply(ERROR_SIP_MESSAGE_GENERIC, [[RestCommClient getErrorText:ERROR_SIP_MESSAGE_GENERIC] UTF8String]);
        reply.Send(ssc->ssc_output_fd);
    }
}

void ssc_i_message(nua_t *nua, ssc_t *ssc,
                   nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                   tagi_t tags[])
{
    /* Incoming message */
    sip_from_t const *from;
    sip_to_t const *to;
    sip_subject_t const *subject;
    std::string username = "john-doe";
    
    assert(sip);
    
    from = sip->sip_from;
    to = sip->sip_to;
    subject = sip->sip_subject;
    
    assert(from && to);
    
    RCLogDebug("%s: new message ", ssc->ssc_name);
    RCLogDebug("\tFrom: %s%s" URL_PRINT_FORMAT "",
           from->a_display ? from->a_display : "", from->a_display ? " " : "",
           URL_PRINT_ARGS(from->a_url));
    if (subject)
        RCLogDebug("\tSubject: %s", subject->g_value);
    ssc_print_payload(ssc, sip->sip_payload);
    
    //if (from && from->a_url->url_user) {
    //    username = from->a_url->url_user;
    //}
    
    char url[1000];
    snprintf(url, sizeof(url), URL_PRINT_FORMAT, URL_PRINT_ARGS(from->a_url));
    
    // notify the client application of the message
    username = url;
    username += "|";  // character that won't show in the username
    username += sip->sip_payload->pl_data;
    
    SofiaReply reply(INCOMING_MSG, username.c_str());
    reply.Send(ssc->ssc_output_fd);
    //setSofiaReply(INCOMING_MSG, "");
    //strcpy(sofiaReply.text, username.c_str());
    //sendSofiaReply(ssc->ssc_output_fd, &sofiaReply);

    
    if (op == NULL)
        op = ssc_oper_create_with_handle(ssc, SIP_METHOD_MESSAGE, nh, from);
    if (op == NULL)
        nua_handle_destroy(nh);
}

void ssc_info(ssc_t *ssc, const char *msg)
{
    ssc_oper_t *op = ssc_oper_find_call(ssc);
    
    if (op) {
        RCLogDebug("%s: sending INFO to %s", ssc->ssc_name, op->op_ident);
        
        nua_info(op->op_handle,
                 SIPTAG_CONTENT_TYPE_STR("application/dtmf-relay"),
                 SIPTAG_PAYLOAD_STR(msg),
                 TAG_END());
    }
    else {
        RCLogDebug("INFO can be send only within an existing call");
    }
}

void ssc_r_info(int status, char const *phrase,
                nua_t *nua, ssc_t *ssc,
                nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                tagi_t tags[])
{
    RCLogDebug("%s: INFO: %d %s", ssc->ssc_name, status, phrase);
    
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
    //sip_subject_t const *subject;
    
    assert(sip);
    
    from = sip->sip_from;
    to = sip->sip_to;
    //subject = sip->sip_subject;
    
    assert(from && to);
    
    RCLogDebug("%s: new info ", ssc->ssc_name);
    RCLogDebug("\tFrom: %s%s" URL_PRINT_FORMAT "",
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
        RCLogDebug("%s: Refer to %s", ssc->ssc_name, op->op_ident);
        
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
    RCLogDebug("%s: refer: %d %s", ssc->ssc_name, status, phrase);
    
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
    //ssc_oper_t *op2;
    char *refer_to_str;
    
    assert(sip);
    
    from = sip->sip_from;
    to = sip->sip_to;
    refer_to = sip->sip_refer_to;
    
    assert(from && to);
    
    RCLogDebug("%s: refer to " URL_PRINT_FORMAT " from %s%s" URL_PRINT_FORMAT "",
           ssc->ssc_name,
           URL_PRINT_ARGS(from->a_url),
           from->a_display ? from->a_display : "", from->a_display ? " " : "",
           URL_PRINT_ARGS(from->a_url));
    
    RCLogDebug("Please follow(i) or reject(c) the refer");
    
    if(refer_to->r_url->url_type == url_sip) {
        refer_to_str = sip_header_as_string(ssc->ssc_home, (sip_header_t*)refer_to);
        ssc_oper_create(ssc, SIP_METHOD_INVITE, refer_to_str,
                              NUTAG_NOTIFY_REFER(nh), TAG_END());
        su_free(ssc->ssc_home, refer_to_str);
    }
    else {
        RCLogDebug("\nPlease Refer to URI: " URL_PRINT_FORMAT "", URL_PRINT_ARGS(refer_to->r_url));
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
        RCLogDebug("%s: Sending re-INVITE with %s to %s",
               ssc->ssc_name, hold ? "hold" : "unhold", op->op_ident);
        
        nua_invite(op->op_handle, NUTAG_HOLD(hold), TAG_END());
        
        op->op_callstate = opc_sent_hold;
    }
    else {
        RCLogDebug("%s: no call to put on hold", ssc->ssc_name);
    }
#else
    RCLogDebug("%s: call hold feature not available.", ssc->ssc_name);
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
        RCLogDebug("%s: SUBSCRIBE %s to %s", ssc->ssc_name, event, op->op_ident);
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
        RCLogDebug("%s: SUBSCRIBE %s to %s", ssc->ssc_name, event, op->op_ident);
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
    RCLogDebug("%s: SUBSCRIBE: %03d %s", ssc->ssc_name, status, phrase);
    
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
        RCLogDebug("%s: not follow refer, NOTIFY(503)", ssc->ssc_name);
        
        nua_cancel(op->op_handle, TAG_END());
        ssc_oper_destroy(ssc, op);
    }
    else {
        RCLogDebug("%s: no REFER to NOTIFY", ssc->ssc_name);
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
            RCLogDebug("%s: NOTIFY from %s", ssc->ssc_name, op->op_ident);
        else
            RCLogDebug("%s: rogue NOTIFY from " URL_PRINT_FORMAT "",
                   ssc->ssc_name, URL_PRINT_ARGS(from->a_url));
        if (event)
            RCLogDebug("\tEvent: %s", event->o_type);
        if (content_type)
            RCLogDebug("\tContent type: %s", content_type->c_type);
        //fputs("\n", stdout);
        ssc_print_payload(ssc, payload);
    }
    else
        RCLogDebug("%s: SUBSCRIBE/NOTIFY timeout for %s", ssc->ssc_name, op->op_ident);
}

/*---------------------------------------*/
void ssc_r_notify(int status, char const *phrase,
                  nua_t *nua, ssc_t *ssc,
                  nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                  tagi_t tags[])
{
    /* Respond to notify */
    RCLogDebug("%s: notify: %d %s", ssc->ssc_name, status, phrase);
    
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
        RCLogDebug("%s: un-SUBSCRIBE to %s", ssc->ssc_name, op->op_ident);
        nua_unsubscribe(op->op_handle, TAG_END());
    }
    else
        RCLogDebug("%s: no subscriptions", ssc->ssc_name);
}

void ssc_r_unsubscribe(int status, char const *phrase,
                       nua_t *nua, ssc_t *ssc,
                       nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                       tagi_t tags[])
{
    RCLogDebug("%s: un-SUBSCRIBE: %03d %s", ssc->ssc_name, status, phrase);
    
    if (status < 200)
        return;
    
    ssc_oper_destroy(ssc, op);
}

// Update settings like AOR, password, registrar
void ssc_update(ssc_t *ssc, const char *aor, const char *password, const char *registrar, const bool unregister)
{
    if (aor) {
        ssc_set_public_address(ssc, aor);
    }
    
    if (!unregister) {
        ssc_register(ssc, registrar, password);
    }
    else {
        ssc_unregister(ssc, registrar, password);
    }
}

void ssc_register(ssc_t *ssc, const char *registrar, const char * password)
{
    char *address;
    ssc_oper_t *op;
    bool registrarless = false;
    
    // check if a registration handle already exists and if so remove it to avoid the issue where:
    // 1. user tries to register with wrong password after a previous registration is successful and is being refreshed periodically
    // 2. even though password for last registration is wrong, previous registration is being refreshed and confuses the user that
    // is left with the impression that no registration is occurring anymore since last was not successful (apart from that it causes
    // the RCDevice state to be invalid)
    /*
    if ((op = ssc_oper_find_by_method(ssc, sip_method_register))) {
        ssc_oper_destroy(ssc, op);
    }
     */
                                 
    // update proxy as well
    if (ssc->ssc_nua) {
        if (registrar && strcmp(registrar, "")) {
            nua_set_params(ssc->ssc_nua,
                           TAG_IF(registrar,
                                  NUTAG_PROXY(registrar)),
                           TAG_IF(registrar,
                                  NUTAG_REGISTRAR(registrar)),
                           TAG_NULL());
        }
        else {
            nua_set_params(ssc->ssc_nua,
                           NUTAG_PROXY(NULL),
                           NUTAG_REGISTRAR(NULL),
                           TAG_NULL());
            registrarless = true;
        }
    }
    
    if (registrarless) {
        return;
    }
    
    //pending_registration = true;
    if (!registrar && (op = ssc_oper_find_by_method(ssc, sip_method_register))) {
        RCLogDebug("REGISTER %s - updating existing registration", op->op_ident);
        nua_register(op->op_handle, TAG_NULL());
        return;
    }
    
    address = su_strdup(ssc->ssc_home, ssc->ssc_address);
    
    if ((op = ssc_oper_create_with_password(ssc, SIP_METHOD_REGISTER, address, password, TAG_END()))) {
        RCLogDebug("REGISTER %s - registering address to network", op->op_ident);
        nua_register(op->op_handle,
                     TAG_IF(registrar, NUTAG_REGISTRAR(registrar)),
                     NUTAG_M_FEATURES("expires=100"),  // set to 100 so that it is sent around 40 - 70 secs (this is how sofia does it at nua_dialog_usage_set_refresh)
                     TAG_NULL());
    }
    else {
        SofiaReply reply(ERROR_SIP_REGISTER_URI_INVALID, [[RestCommClient getErrorText:ERROR_SIP_REGISTER_URI_INVALID] UTF8String]);
    }

    su_free(ssc->ssc_home, address);
}

void ssc_r_register(int status, char const *phrase,
                    nua_t *nua, ssc_t *ssc,
                    nua_handle_t *nh, ssc_oper_t *op, sip_t const *sip,
                    tagi_t tags[])
{
    //sip_contact_t *m = sip ? sip->sip_contact : NULL;
    
    RCLogNotice("REGISTER: %03d %s", status, phrase);
    
    if (status < 200)
        return;
    
    if (status == 401 || status == 407)
        ssc_store_pending_auth(ssc, op, sip, tags);
    else if (status >= 300) {
        // Error
        RCLogError("REGISTER failed: %03d %s", status, phrase);
        ssc_oper_destroy(ssc, op);
        //RCLogNotice("Got failed REGISTER response but silencing it since another registration has been successfully handled afterwards");
        if (status == 403) {
            // authentication error
            SofiaReply reply(ERROR_SIP_REGISTER_AUTHENTICATION, [[RestCommClient getErrorText:ERROR_SIP_REGISTER_AUTHENTICATION] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 408) {
            // timeout error
            SofiaReply reply(ERROR_SIP_REGISTER_TIMEOUT, [[RestCommClient getErrorText:ERROR_SIP_REGISTER_TIMEOUT] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else if (status == 503) {
            // timeout error
            SofiaReply reply(ERROR_SIP_REGISTER_SERVICE_UNAVAILABLE, [[RestCommClient getErrorText:ERROR_SIP_REGISTER_SERVICE_UNAVAILABLE] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
        else {
            // generic error
            RCLogError("REGISTER Unknown error: %03d %s", status, phrase);
            SofiaReply reply(ERROR_SIP_REGISTER_GENERIC, [[RestCommClient getErrorText:ERROR_SIP_REGISTER_GENERIC] UTF8String]);
            reply.Send(ssc->ssc_output_fd);
        }
    }
    else if (status == 200) {
        RCLogDebug("Succesfully registered %s to network", ssc->ssc_address);
        //pending_registration = false;
        SofiaReply reply(REGISTER_SUCCESS, phrase);
        reply.Send(ssc->ssc_output_fd);

        if (ssc->ssc_registration_cb)
            ssc->ssc_registration_cb (ssc, 1, ssc->ssc_cb_context);
        // TODO: would be helpful to print the header, but the fact that this routine only works with streams, makes it difficult
        /*
        for (m = sip ? sip->sip_contact : NULL; m; m = m->m_next) {
            sl_header_print(stdout, "\tContact: %s", (sip_header_t *)m);
        }
         */
        
    }
}

void ssc_unregister(ssc_t *ssc, const char *registrar, const char *password)
{
    ssc_oper_t *op;
    
    // update proxy as well
    if (ssc->ssc_nua) {
        nua_set_params(ssc->ssc_nua,
                       NUTAG_PROXY(NULL),
                       NUTAG_REGISTRAR(NULL),
                       TAG_NULL());
    }

    if (!registrar && (op = ssc_oper_find_by_method(ssc, sip_method_register))) {
        RCLogDebug("un-REGISTER %s", op->op_ident);
        nua_unregister(op->op_handle, TAG_NULL());
        return;
    }
    else {
        char *address = su_strdup(ssc->ssc_home, ssc->ssc_address);
        op = ssc_oper_create_with_password(ssc, SIP_METHOD_REGISTER, address, password, TAG_END());
        su_free(ssc->ssc_home, address);
        
        if (op) {
            RCLogDebug("%s: un-REGISTER %s%s%s", ssc->ssc_name, 
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
    //sip_contact_t *m;
    
    RCLogNotice("un-REGISTER: %03d %s", status, phrase);
    
    if (status < 200)
        return;
    
    if (status == 200) {
        if (ssc->ssc_registration_cb)
            ssc->ssc_registration_cb (ssc, 0, ssc->ssc_cb_context);
        // TODO
        /*
        for (m = sip ? sip->sip_contact : NULL; m; m = m->m_next) {
            sl_header_print(stdout, "\tContact: %s", (sip_header_t *)m);
        }
         */
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
        RCLogDebug("%s %s", op->op_method_name, op->op_ident);
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
        RCLogDebug("%s: %s %s", ssc->ssc_name, op->op_method_name, op->op_ident);
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
        RCLogDebug("%s: %s %s", ssc->ssc_name, op->op_method_name, op->op_ident);
        nua_publish(op->op_handle, 
                    SIPTAG_EXPIRES_STR("0"),
                    TAG_NULL());
        return;
    }
    
    address = su_strdup(ssc->ssc_home, ssc->ssc_address);
    
    if ((op = ssc_oper_create(ssc, SIP_METHOD_PUBLISH, address, 
                              SIPTAG_EVENT_STR("presence"),
                              TAG_END()))) {
        RCLogDebug("%s: un-%s %s", ssc->ssc_name, op->op_method_name, op->op_ident);
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
    RCLogDebug("%s: PUBLISH: %03d %s", ssc->ssc_name, status, phrase);
    
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
    // TODO: Unfortunately there's an issue (probably Sofia SIP internal?), that causes ssc_r_shutdown
    // to never be called with status code 200 (it's only called with 100), to signify that stack
    // has been shutdown properly. So what we do is a hack where when we get the 100, which always arrives,
    // we just break out of the sofia runloop. Some additional notes:
    // - In iOS to make sure that it's not the OS's fault that stops the process I tried this when the App
    //   is not being backgrounded (which is the typical case) and we have the same issue still even after
    //   several seconds -I even waited for 120 seconds!
    // - To make sure that Sofia thread has enough time to finish shutting down before iOS stops it, in the
    //   higher layers of the SDK we call UIApplication.beginBackgroundTaskWithExpirationHandler and ask
    //   more time
    // - When we get around to implementing our refactoring we should 1. Investigate the Sofia SIP issue
    //   more and try to fix it, 2. Provide callback when shutdown is properly completed, and use that
    //   callback to stop the iOS background task by calling UIApplication.endBackgroundTask
    
     
    RCLogDebug("%s: nua_shutdown: %03d %s", ssc->ssc_name, status, phrase);
    static int attempt = 0;

    /*
    nua_destroy(nua);
    su_root_break(ssc->ssc_root);
     */

    if (status == 100) {
        RCLogDebug("Forcing Sofia SIP to complete shutdown: breaking out of loop");
        //nua_destroy(nua);
        su_root_break(ssc->ssc_root);
    }

    /*
    if (status == 101) {
        // shut down in progress
        if (attempt >= 3) {
            RCLogDebug("Sofia failed to shutdown gracefully after 3 attempts: breaking out of loop");
            //nua_destroy(nua);
            su_root_break(ssc->ssc_root);
            attempt = 0;
        }
        attempt++;
    }
     */
    
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
    
    RCLogDebug("%s: nua_r_getparams: %03d %s", ssc->ssc_name, status, phrase);
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
    
    //RCLogDebug("\nStarting sofsip-cli in interactive mode. Issue 'h' to get list of available commands.");
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
    RCLogDebug("SIP address...........: %s", ssc->ssc_address);
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
                ns = const_cast<char*>("found");
                break;
            }
        }
    if (!ns || strcmp(ns, "nta") == 0) 
        for (list = nta_tag_list; (tag = *list); list++) {
            if (strcmp(tag->tt_name, param) == 0) {
                ns = const_cast<char*>("found");
                break;
            }
        }
    if (!ns || strcmp(ns, "sip") == 0) 
        for (list = sip_tag_list; (tag = *list); list++) {
            if (strcmp(tag->tt_name, param) == 0) {
                ns = const_cast<char*>("found");
                break;
            }
        }
    
    
    if (!tag) {
        RCLogDebug("sofsip: unknown parameter %s::%s",  
               ns ? ns : "", param);
        return;
    }
    
    scanned = t_scan(tag, home, s, &value);
    if (scanned <= 0) {
        RCLogDebug("sofsip: invalid value for %s::%s",  
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
    
    RCLogDebug("%s: quitting (this can take some time)", ssc->ssc_name);
    
    nua_shutdown(ssc->ssc_nua);
    
    //nua_destroy(ssc->ssc_nua);
    
    //su_root_break(ssc->ssc_root);
    
    stackIsShuttingDown = true;
}

string resolveSipUri(string uri)
{
    string result = "";
    // resolve manually as Sofia in iOS doesn't work by default (/etc/resolv.conf is not accessible)
    stringstream ss(uri);
    string item;
    vector<string> items;
    // registrar has the form: sip:dns/ip addr:5080
    while (std::getline(ss, item, ':')) {
        items.push_back(item);
    }
    if (items.size() != 3) {
        RCLogError("Error parsing URI: ", uri.c_str());
        return "";
    }
    
    struct hostent *host_entry = gethostbyname(items[1].c_str());
    char *resolved = NULL;
    resolved = inet_ntoa(*((struct in_addr *)host_entry->h_addr_list[0]));
    if (resolved == NULL) {
        RCLogError("Error resolving %s", uri.c_str());
        return "";
    }
    
    string full_uri = items[0] + ":" + resolved + ":" + items[2];
    return full_uri;
}

/*
// reply sent back to the iOS App via pipe
void setSofiaReply(const int rc, const char * text)
{
    sofiaReply.rc = rc;
    strncpy(sofiaReply.text, text, sizeof(sofiaReply.text) - 1);
    sofiaReply.text[sizeof(sofiaReply.text) - 1] = 0;
}

void setSofiaReplyPtr(const int rc, void * ptr)
{
    sofiaReply.rc = rc;
    //int value = ptr;
    strncpy(sofiaReply.text, (char *)ptr, sizeof(ptr));
    sofiaReply.text[sizeof(void *)] = 0;
}

struct SofiaReply * getSofiaReply(void)
{
    return &sofiaReply;
}


ssize_t sendSofiaReply(const int fd, const struct SofiaReply * sofiaReply)
{
    //char buf[100] = "auth";
    int size = sizeof(*sofiaReply);
    return write(fd, sofiaReply, size);
}
*/
