/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005-2006 Nokia Corporation.
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
 *  - separete ssc_t into sofsip_cli and ssc_sip specific
 *    structs
 *
 * Notes:
 *  - none
 */

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>

//#if HAVE_GLIB
//#include <glib.h>
//#define HAVE_MEDIA_IMPL 1
//#else
//#define HAVE_MEDIA_IMPL 0
//#endif

#include <sofia-sip/su.h>

#include "ssc_sip.h"
#include "ssc_oper.h"
#include "common.h"

/**
 * Creates a new operation object and stores it the list of
 * active operations for 'cli'.
 */
ssc_oper_t *ssc_oper_create(ssc_t *ssc, 
			    sip_method_t method,
			    char const *name,
			    char const *address,
			    tag_type_t tag, tag_value_t value, ...)
{
  ssc_oper_t *op, *old;

  ta_list ta;
   
  enter;

  for (old = ssc->ssc_operations; old; old = old->op_next)
    if (!old->op_persistent)
      break;

  if (address) {
    int have_url = 1;
    sip_to_t *to;

    to = sip_to_make(ssc->ssc_home, address);

    if (to == NULL) {
      RCLogDebug("%s: %s: invalid address: %s\n", ssc->ssc_name, name, address);
      return NULL;
    }

    /* Try to make sense out of the URL */
    if (url_sanitize(to->a_url) < 0) {
      RCLogDebug("%s: %s: invalid address\n", ssc->ssc_name, name);
      return NULL;
    }

    if (!(op = (ssc_oper_t*)su_zalloc(ssc->ssc_home, sizeof(*op)))) {
      RCLogDebug("%s: %s: cannot create handle\n", ssc->ssc_name, name);
      return NULL;
    }

    op->op_next = ssc->ssc_operations;
    op->op_prev_state = -1;
    op->op_ssc = ssc;
    ssc->ssc_operations = op;
    op->password = NULL;

    if (method == sip_method_register)
      have_url = 0;
    
    ta_start(ta, tag, value); 
     
    op->op_handle = nua_handle(ssc->ssc_nua, op, 
			       TAG_IF(have_url, NUTAG_URL(to->a_url)), 
			       SIPTAG_TO(to),
			       ta_tags(ta));

    ta_end(ta);  
     
    op->op_ident = sip_header_as_string(ssc->ssc_home, (sip_header_t *)to);

    ssc_oper_assign(op, method, name);
    
    if (!op->op_persistent) {
      ssc_oper_t *old_next;
      for (; old; old = old_next) {      /* Clean old handles */
	old_next = old->op_next;
	if (!old->op_persistent && !old->op_callstate)
	  ssc_oper_destroy(ssc, old);
      }
    }
    
    su_free(ssc->ssc_home, to);
  }
  else if (method || name) 
    ssc_oper_assign(op = old, method, name);
  else
    return old;

  if (!op) {
    if (address)
      RCLogDebug("%s: %s: invalid destination\n", ssc->ssc_name, name);
    else
      RCLogDebug("%s: %s: no destination\n", ssc->ssc_name, name);
    return NULL;
  }

  return op;
}

/**
 * Creates a new operation object with a password (applicable to REGISTER handles) and stores it the list of
 * active operations for 'cli'.
 */
ssc_oper_t *ssc_oper_create_with_password(ssc_t *ssc,
                            sip_method_t method,
                            char const *name,
                            char const *address,
                            char const *password,
                            tag_type_t tag, tag_value_t value, ...)
{
    ssc_oper_t *op = ssc_oper_create(ssc, method, name, address, tag, value);
    if (op) {
        op->password = su_strdup(ssc->ssc_home, password);
    }
    return op;
}

/**
 * Creates an operation handle and binds it to
 * an existing handle 'nh' (does not create a new nua 
 * handle with nua_handle()).
 */
ssc_oper_t *ssc_oper_create_with_handle(ssc_t *ssc, 
					sip_method_t method,
					char const *name,
					nua_handle_t *nh,
					sip_from_t const *from)
{
  ssc_oper_t *op;

  enter;

  if ((op = (ssc_oper_t*)su_zalloc(ssc->ssc_home, sizeof(*op)))) {
    op->op_next = ssc->ssc_operations;
    ssc->ssc_operations = op;      

    ssc_oper_assign(op, method, name);
    nua_handle_bind(op->op_handle = nh, op);
    op->op_ident = sip_header_as_string(ssc->ssc_home, (sip_header_t*)from);
    op->op_ssc = ssc;
    op->password = NULL;
  }
  else {
    RCLogDebug("%s: cannot create operation object for %s\n", 
	   ssc->ssc_name, name);
  }

  return op;
}

/** 
 * Deletes operation and attached handles and identities 
 */
void ssc_oper_destroy(ssc_t *ssc, ssc_oper_t *op)
{
  ssc_oper_t **prev;
  int active_invites = 0;

  if (!op)
    return;

  /* Remove from queue */
  for (prev = &ssc->ssc_operations; 
       *prev && *prev != op; 
       prev = &(*prev)->op_next)
    ;
  if (*prev)
    *prev = op->op_next, op->op_next = NULL;

  if (op->op_handle)
    nua_handle_destroy(op->op_handle), op->op_handle = NULL;

  for (prev = &ssc->ssc_operations; 
       *prev; 
       prev = &(*prev)->op_next) {
    if ((*prev)->op_method == sip_method_invite) ++active_invites;
  }

  if (active_invites == 0) {
    /* last INVITE operation */
//#if HAVE_MEDIA_IMPL
    if (ssc->ssc_media->ssc_media_is_initialized() == true)
      ssc->ssc_media->ssc_media_deactivate();
//#endif
  }

  if (op->password) {
     su_free(ssc->ssc_home, op->password);
  }
  su_free(ssc->ssc_home, op);
}

/**
 * Assigns flags to operation object based on method type
 */
void ssc_oper_assign(ssc_oper_t *op, sip_method_t method, char const *name)
{
  if (!op)
    return;

  op->op_method = method, op->op_method_name = name;

  op->op_persistent = 
    method == sip_method_subscribe ||
    method == sip_method_register ||
    method == sip_method_publish;
}

/**
 * Finds a call operation (an operation that has non-zero
 * op_callstate).
 */
ssc_oper_t *ssc_oper_find_call(ssc_t *ssc)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_callstate)
      break;

  return op;
}

/**
 * Finds call operation that is in process.
 */
ssc_oper_t *ssc_oper_find_call_in_progress(ssc_t *ssc)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_callstate & opc_sent) /* opc_sent bit is on? */
      break;

  return op;
}

ssc_oper_t *ssc_oper_find_call_embryonic(ssc_t *ssc)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_callstate == 0 && op->op_method == sip_method_invite)
      break;

  return op;
}
  
/**
 * Finds an unanswered call operation.
 */
ssc_oper_t *ssc_oper_find_unanswered(ssc_t *ssc)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_callstate == opc_recv)
      break;

  return op;
}

/**
 * Finds an operation by nua handle.
 */
ssc_oper_t *ssc_oper_find_by_handle(ssc_t *ssc, nua_handle_t *handle)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_handle == handle)
      break;

  return op;
}

/**
 * Finds an operation by method.
 */
ssc_oper_t *ssc_oper_find_by_method(ssc_t *ssc, sip_method_t method)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_method == method && op->op_persistent)
      break;

  return op;
}

/** 
 * Finds an operation by call state
 */
ssc_oper_t *ssc_oper_find_by_callstate(ssc_t *ssc, int callstate)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_callstate & callstate)
      break;

  return op;
}

/**
 * Find a register operation.
 */
ssc_oper_t *ssc_oper_find_register(ssc_t *ssc)
{
  ssc_oper_t *op;

  for (op = ssc->ssc_operations; op; op = op->op_next)
    if (op->op_method == sip_method_register && op->op_persistent)
      break;

  return op;
}

/**
 * Checks whether 'op' is a valid handle or not.
 *
 * @return op if valid, NULL otherwise
 */
ssc_oper_t *ssc_oper_check(ssc_t *ssc, ssc_oper_t *op)
{
  ssc_oper_t *tmp;

  for (tmp = ssc->ssc_operations; tmp; tmp = op->op_next)
    if (tmp == op)
      return op;

  return NULL;
}
