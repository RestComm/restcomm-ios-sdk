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

/**@file sdpg_utils.c
 * 
 * Utilizies for glib/gstreamer applications handling 
 * for handling SDP.
 *
 * @author Kai Vehmanen <kai.vehmanen@nokia.com>
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

//#include "glib.h"
#include <stdio.h>
#include <string.h>

#include "sdp_utils.h"

#include <sofia-sip/sdp.h>

/**
 * Converts SDP 'parser' to text. Pointer to the
 * created output is stored to 'sdp_str', NULL if 
 * operation fails.
 *
 * Caller is responsible for g_free()ing the memory
 * allocated for 'sdp_str'.
 *
 * @return zero on success, non-zero on error
 */
/* removing glib dependency causes leak -let's leave this out for now
int sdp_print_to_text(su_home_t *home, sdp_parser_t *parser, char **sdp_str)
{
  int res = -1;
  *sdp_str = NULL;
  
  if (sdp_session(parser)) {
    sdp_session_t *sdp = sdp_session(parser);
    sdp_printer_t *printer = sdp_print(home, sdp, NULL, 0, sdp_f_config | sdp_f_insane);
    if (!sdp_printing_error(printer)) {
      *sdp_str = g_strdup(sdp_message(printer));
      res = 0;
    }
    else {
      fprintf(stderr, "%s: error printing SDP: %s\n", __func__, sdp_printing_error(printer));
    }
    sdp_printer_free(printer);
  } else {
    fprintf(stderr, "%s: invalid SDP.\n", __func__);
  }

  return res;
}
 */


/**
 * Sets the contact line value of 'media'
 * to 'contact'.
 *
 * See sofia-sip/libsofia-sip-ua/sdp/sdp_parse.c:parse_connection()
 *
 * @return non-zero on error
 */
int sdp_set_contact(sdp_parser_t *parser, sdp_media_t *media, sdp_nettype_e ntype, sdp_addrtype_e atype, const char *c_addr)
{
  int result = 0;
  su_home_t *home = sdp_parser_home(parser);
  sdp_connection_t *sdp_connection = media->m_connections;

  /* note: we use the SDP parser home to ensure proper 
   *       cleanup of the SDP structures */

  /* clone the session level c-line if needed */
  if (!sdp_connection) {
    sdp_connection = sdp_connection_dup(home, sdp_media_connections(media));
    media->m_connections = sdp_connection;
  }

  if (!sdp_connection) {
    sdp_connection = (sdp_connection_t*)su_salloc(home, sizeof(*sdp_connection));
    media->m_connections = sdp_connection;
  }

  /* set network and address types */
  sdp_connection->c_nettype = ntype;
  sdp_connection->c_addrtype = atype;
  
  /* note: the old address will be free when SDP parser
     home is freed */

  /* set the connection address */
  sdp_connection->c_address = su_strdup(home, c_addr);

  return result;
}
