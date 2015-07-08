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

#ifndef HAVE_SDP_UTILS_H
#define HAVE_SDP_UTILS_H

#include <sofia-sip/sdp.h>

//int sdp_print_to_text(su_home_t *home, sdp_parser_t *parser, char **sdp_str);

int sdp_set_contact(sdp_parser_t *parser, sdp_media_t *media, sdp_nettype_e ntype, sdp_addrtype_e atype, const char *caddress);


#endif /* HAVE_SDP_UTILS_H */
