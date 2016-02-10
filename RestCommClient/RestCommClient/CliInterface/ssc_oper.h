/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2006 Nokia Corporation.
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

#ifndef HAVE_SSC_OPER_H
#define HAVE_SSC_OPER_H

/**@file ssc_oper.h Handling active operations initated 
 *       by the application.
 *
 * @author Kai Vehmanen <Kai.Vehmanen@nokia.com>
 * @author Pekka Pessi <Pekka.Pessi@nokia.com>
 */

typedef struct ssc_oper_s ssc_oper_t;

/* define type of context pointers for callbacks */
#define NUA_IMAGIC_T    ssc_oper_t
#define NUA_HMAGIC_T    ssc_oper_t

#include <sofia-sip/nua.h>
#include <sofia-sip/sip.h>
#include <sofia-sip/sip_header.h>
#include <sofia-sip/sip_status.h>
#include <sofia-sip/su_debug.h>

#if HAVE_FUNC
#define enter (void)SU_DEBUG_9(("%s: entering\n", __func__))
#elif HAVE_FUNCTION
#define enter (void)SU_DEBUG_9(("%s: entering\n", __FUNCTION__))
#else
#define enter (void)0
#endif

/** Call state.
 *
 * - opc_sent when initial INVITE has been sent
 * - opc_recv when initial INVITE has been received
 * - opc_complate when 200 Ok has been sent/received
 * - opc_active when media is used
 * - opc_sent when re-INVITE has been sent
 * - opc_recv when re-INVITE has been received
 */
enum op_callstate_t {
    opc_none,
    opc_sent = 1,
    opc_recv = 2,
    opc_complete = 3,
    opc_active = 4,
    opc_sent_hold = 8,             /**< Call put on hold */
    opc_pending = 16               /**< Waiting for local resources */
};

struct ssc_oper_s {
  ssc_oper_t   *op_next;

  /**< Remote end identity
   *
   * Contents of To: when initiating, From: when receiving.
   */
  char const   *op_ident;	

  /** NUA handle */ 
  nua_handle_t *op_handle;
  
  ssc_t        *op_ssc;         /**< backpointer to owner */
  bool         is_outgoing;      // for calls, if outgoing true, else false
  char         *custom_headers;
  /** How this handle was used initially */
  sip_method_t  op_method;	/**< REGISTER, INVITE, MESSAGE, or SUBSCRIBE */
  char const   *op_method_name;
  char         *password;

  enum op_callstate_t op_callstate;
  int           op_prev_state;     /**< Previous call state */

  unsigned      op_persistent : 1; /**< Is this handle persistent? */
  unsigned      op_referred : 1;
  unsigned :0;
};

ssc_oper_t *ssc_oper_create(ssc_t *ssc, 
			    sip_method_t method,
			    char const *name,
			    char const *address,
			    tag_type_t tag, tag_value_t value, ...);
ssc_oper_t *ssc_oper_create_with_password(ssc_t *ssc,
                                          sip_method_t method,
                                          char const *name,
                                          char const *address,
                                          char const *password,
                                          tag_type_t tag, tag_value_t value, ...);
ssc_oper_t *ssc_oper_create_with_handle(ssc_t *ssc, 
					sip_method_t method,
					char const *name,
					nua_handle_t *nh,
					sip_from_t const *from);
void ssc_oper_destroy(ssc_t *ssc, ssc_oper_t *op);
void ssc_oper_assign(ssc_oper_t *op, sip_method_t method, char const *name);
ssc_oper_t *ssc_oper_find_call(ssc_t *ssc);
ssc_oper_t *ssc_oper_find_call_in_progress(ssc_t *ssc);
ssc_oper_t *ssc_oper_find_call_embryonic(ssc_t *ssc);
ssc_oper_t *ssc_oper_find_unanswered(ssc_t *ssc);
ssc_oper_t *ssc_oper_find_by_handle(ssc_t *ssc, nua_handle_t *handle); 
ssc_oper_t *ssc_oper_find_by_method(ssc_t *ssc, sip_method_t method);
ssc_oper_t *ssc_oper_find_by_callstate(ssc_t *ssc, int callstate);
ssc_oper_t *ssc_oper_find_register(ssc_t *ssc);
ssc_oper_t *ssc_oper_check(ssc_t *ssc, ssc_oper_t *op);

#endif /* HAVE_SSC_OPER_H */
