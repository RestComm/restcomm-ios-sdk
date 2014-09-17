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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_GST

#include <stdio.h>
#include <errno.h>
#include <string.h>

#include <glib.h>
#include <glib-object.h>
#include <gst/gst.h>

#include "ssc_media_gst_utils.h"

/* audio subsystem type identifying N770 (for special case code) */
static const char *priv_n770_mode_str = "N770"; 

/**
 * Creates a GstCaps object from the pt-codec mapping
 * described by 'rtpmap'.
 *
 * The caller is responsible for freeing the GstCaps
 * object.
 *
 * @return the GstCaps object on success, NULL on error
 */
GstCaps *gsdp_rtpmap_to_caps(sdp_rtpmap_t *rtpmap)
{
  GstCaps *caps = NULL;
#if HAVE_GST
  sdp_rtpmap_t *i;
  gchar *str = NULL;

  /* see gst-plugins-good-cvs/gst/rtp/README */

  /*
  "application/x-rtp",
      "media", G_TYPE_STRING, "audio",		-]
      "payload", G_TYPE_INT, 96,                 ] - required
      "clock-rate", G_TYPE_INT, 8000,           -]
      "encoding-name", G_TYPE_STRING, "AMR",    -] - required since payload >= 96
      "encoding-params", G_TYPE_STRING, "1",	-] - optional param for AMR
      "octet-align", G_TYPE_STRING, "1",	-]
      "crc", G_TYPE_STRING, "0",                 ]
      "robust-sorting", G_TYPE_STRING, "0",      ]  AMR specific params.
      "interleaving", G_TYPE_STRING, "0",       -]
  */

  for(i = rtpmap; i; i = i->rm_next) {
    /* XXX: to-be-defined */
  }

  if (str) 
    caps = gst_caps_from_string(str);

#endif

  return caps;
}

/**
 * Returns a set of codec factories for codec 'codecname'.
 * 
 * The caller is responsible for freeing the factories
 * object (with gsdp_codec_factories_free()).
 *
 * @return the GstCaps object on success, NULL on error
 */
gsdp_codec_factories_t *gsdp_codec_factories_create(const char *codecname)
{
#if HAVE_GST
  gsdp_codec_factories_t *f = g_new0(gsdp_codec_factories_t, 1);

  if (strstr(codecname, "GSM")) {
    f->payloader = gst_element_factory_find ("rtpgsmpay");
    f->depayloader = gst_element_factory_find ("rtpgsmdepay");
    f->encoder = gst_element_factory_find ("gsmenc");
    f->decoder = gst_element_factory_find ("gsmdec");
  }
  else if (strstr(codecname, "PCMU")) {
    f->payloader = gst_element_factory_find ("rtpg711pay");
    if (f->payloader) {
      f->depayloader = gst_element_factory_find ("rtpg711depay");
    }
    else {
      f->payloader = gst_element_factory_find ("rtppcmupay");
      f->depayloader = gst_element_factory_find ("rtppcmudepay");
    }
    f->encoder = gst_element_factory_find ("mulawenc");
    f->decoder = gst_element_factory_find ("mulawdec");
  }
  else if (strstr(codecname, "PCMA")) {
    f->payloader = gst_element_factory_find ("rtpg711pay");
    if (f->payloader) {
      f->depayloader = gst_element_factory_find ("rtpg711depay");
    }
    else {
      f->payloader = gst_element_factory_find ("rtppcmapay");
      f->depayloader = gst_element_factory_find ("rtppcmadepay");
    }
    f->encoder = gst_element_factory_find ("alawenc");
    f->decoder = gst_element_factory_find ("alawdec");
  }
  else {
    /* unknown codec */
    g_free(f);
    f = NULL;
  }
  return f;
#else
  return NULL;
#endif

}

/**
 * Frees the codec factories created with gsdp_codec_factories_create().
 *
 * @return the GstCaps object on success, NULL on error
 */
void gsdp_codec_factories_free(gsdp_codec_factories_t *f)
{
#if HAVE_GST
  const char * const ad_type_getenv = getenv("SOFSIP_AUDIO");
  const char *ad_type = SOFSIP_DEFAULT_AUDIO;
#endif
  g_assert(f != NULL);
#if HAVE_GST
  gst_object_unref(f->payloader);
  gst_object_unref(f->depayloader);

  if (ad_type_getenv)
    ad_type = ad_type_getenv;
  if(strcmp(ad_type, priv_n770_mode_str) != 0) {
    gst_object_unref(f->encoder);
    gst_object_unref(f->decoder);
  }
#endif
  g_free(f);
}

GstElement* ssc_media_create_audio_src(const char* type)
{
  GstElementFactory *factory;
  GstElement *res = NULL;
  GList *i; 

  i = gst_registry_get_feature_list (gst_registry_get_default(), GST_TYPE_ELEMENT_FACTORY);

  while(i) {
    factory = GST_ELEMENT_FACTORY(i->data);
    if (factory) {
      const char* klass_tags = gst_element_factory_get_klass(factory);
      if (strstr(klass_tags, "Audio") && 
	  (strstr(klass_tags, "Source") || strstr(klass_tags, "Src")) &&
	  strstr(gst_element_factory_get_longname(factory), type)) {
	/* g_debug("%s: match of %s and %s (tags:%s).\n", __func__, gst_element_factory_get_longname(factory), type, klass_tags); */
	res = gst_element_factory_create(factory, "audiosrc");
	break;
      }
    }
    i = g_list_next(i);
  }

  return res;
}

GstElement* ssc_media_create_audio_sink(const char* type)
{
  GstElementFactory *factory;
  GstElement *res = NULL;
  GList *i; 

  i = gst_registry_get_feature_list (gst_registry_get_default(), GST_TYPE_ELEMENT_FACTORY);

  while(i) {
    factory = GST_ELEMENT_FACTORY(i->data);
    if (factory) {
      const char* klass_tags = gst_element_factory_get_klass(factory);
      if (strstr(klass_tags, "Sink") && strstr(klass_tags, "Audio") &&
	  strstr(gst_element_factory_get_longname(factory), type))  {
	/* g_debug("%s: match of %s and %s (tags:%s).\n", __func__, gst_element_factory_get_longname(factory), type, klass_tags); */
	res = gst_element_factory_create(factory, "audiosink");
	break;
      }
    }
    i = g_list_next(i);
  }

  return res;
}

#endif /* HAVE_GST */
