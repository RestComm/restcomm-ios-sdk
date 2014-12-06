/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005-2006,2009 Nokia Corporation.
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

/**@file ssc_media_gst.h GST-based implementation of ssc_media.h
 *                       interface.
 *
 * @author Kai Vehmanen <Kai.Vehmanen@nokia.com>
 */

#ifndef HAVE_SSC_MEDIA_GST_H
#define HAVE_SSC_MEDIA_GST_H

#include <glib.h>
#include <glib-object.h>
#include <gst/gst.h>

#include <unistd.h>
#include <netinet/in.h>

#include <sofia-sip/su.h>

#include "ssc_media.h"
#include "farsight-netsocket.h"

G_BEGIN_DECLS

typedef struct _SscMediaGst        SscMediaGst;
typedef struct _SscMediaGstClass   SscMediaGstClass;

GType ssc_media_gst_get_type(void);

/* TYPE MACROS */
#define SSC_MEDIA_GST_TYPE \
  (ssc_media_gst_get_type())
#define SSC_MEDIA_GST(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), SSC_MEDIA_GST_TYPE, SscMediaGst))
#define SSC_MEDIA_GST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), SSC_MEDIA_GST_TYPE, SscMediaGstClass))
#define SSC_IS_MEDIA_GST(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), SSC_MEDIA_GST_TYPE))
#define SSC_IS_MEDIA_GST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), SSC_MEDIA_GST_TYPE))
#define SSC_MEDIA_GST_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), SSC_MEDIA_GST_TYPE, SscMediaGstClass))


struct _SscMediaGstClass {
  SscMediaClass parent_class;
};

struct _SscMediaGst {
  SscMedia parent;
    
  /* scope/protected: 
   * ---------------- */

  FarsightNetsocket* sm_netsocket;
  int           sm_rtp_sockfd;
  int           sm_rtcp_sockfd;
  guint16       sm_rtp_lport;
  guint32       sm_pt;
  GstElement   *sm_pipeline;         
  GstElement   *sm_udpsrc;           /**< owned by gst-pipeline */ 
  GstElement   *sm_udpsink;          /**< owned by gst-pipeline */ 
  GstElement   *sm_depay;            /**< owned by gst-pipeline */ 
  GstElement   *sm_decoder;          /**< owned by gst-pipeline */ 
  char         *sm_ad_input_type;
  char         *sm_ad_input_device;
  char         *sm_ad_output_type;
  char         *sm_ad_output_device;
  char         *sm_stun_server;
  char         *sm_stun_domain;
  gboolean      sm_rx_elements;
  gboolean      sm_tx_elements;
  gboolean      dispose_run;
};

#endif /* HAVE_SSC_MEDIA_GST_H */
