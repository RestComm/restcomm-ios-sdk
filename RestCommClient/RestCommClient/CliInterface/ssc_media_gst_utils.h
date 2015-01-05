/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005-2006 Nokia Corporation.
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

#ifndef HAVE_SSC_MEDIA_GST_UTILS_H
#define HAVE_SSC_MEDIA_GST_UTILS_H

#if HAVE_GST
#include <gst/gst.h>
#else
typedef void GstElementFactory;
typedef void GstCaps;
#endif

#include <sofia-sip/sdp.h>

typedef struct gsdp_codec_factories gsdp_codec_factories_t;

/**
 * Set of GstElementFactory objects that can be used
 * to generate the necessary payloader, encoder, decoder
 * and depayloader elements for a given codec.
 */ 
struct gsdp_codec_factories {
  GstElementFactory *payloader;
  GstElementFactory *depayloader;
  GstElementFactory *encoder;
  GstElementFactory *decoder;
};

enum ssc_media_state {
  sm_state_inactive,
  sm_state_active,
  sm_state_error
};

GstCaps *gsdp_rtpmap_to_caps(sdp_rtpmap_t *rtpmap);
gsdp_codec_factories_t *gsdp_codec_factories_create(const char *codecname);
void gsdp_codec_factories_free(gsdp_codec_factories_t *f);

GstElement* ssc_media_create_audio_src(const char* type);
GstElement* ssc_media_create_audio_sink(const char* type);

#endif /* HAVE_SSC_MEDIA_GST_UTILS_H */

