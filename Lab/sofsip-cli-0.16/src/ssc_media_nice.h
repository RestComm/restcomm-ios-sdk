/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2007 Nokia Corporation.
 * Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation.
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

/**@file ssc_media_nice.h NICE implementation of 
 *                        ssc_media.h interface.
 *
 * @author Kai Vehmanen <Kai.Vehmanen@nokia.com>
 */

#ifndef HAVE_SSC_MEDIA_NICE_H
#define HAVE_SSC_MEDIA_NICE_H

#include <glib.h>
#include <glib-object.h>

#include <unistd.h>
#include <netinet/in.h>

#include <sofia-sip/su.h>

#include <nice/nice.h>

#include "ssc_media.h"

G_BEGIN_DECLS

typedef struct _SscMediaNice        SscMediaNice;
typedef struct _SscMediaNiceClass   SscMediaNiceClass;

GType ssc_media_nice_get_type(void);

/* TYPE MACROS */
#define SSC_MEDIA_NICE_TYPE \
  (ssc_media_nice_get_type())
#define SSC_MEDIA_NICE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), SSC_MEDIA_NICE_TYPE, SscMediaNice))
#define SSC_MEDIA_NICE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), SSC_MEDIA_NICE_TYPE, SscMediaNiceClass))
#define SSC_IS_MEDIA_NICE(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), SSC_MEDIA_NICE_TYPE))
#define SSC_IS_MEDIA_NICE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), SSC_MEDIA_NICE_TYPE))
#define SSC_MEDIA_NICE_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), SSC_MEDIA_NICE_TYPE, SscMediaNiceClass))


struct _SscMediaNiceClass {
  SscMediaClass parent_class;
};

struct _SscMediaNice {
  SscMedia parent;
    
  /* scope/protected: 
   * ---------------- */

  gboolean      dispose_run;

  NiceAgent    *agent;
  guint         stream_id;
  gboolean      gathering_done;
  guint         dummy_timer_id;
  NiceComponentState rtp_state;
  NiceComponentState rtcp_state;
  guint         rtp_packets_received;
  guint         nice_test_packets_received;
  guint         nice_test_packets_sent;
  guint         nice_test_failed;
  guint         looped_rtp_packets;
  gchar        *sm_stun_server;
  gchar        *local_rtp_foundation;
  gchar        *local_rtcp_foundation;
  guint32       ssrc;
};

#endif /* HAVE_SSC_MEDIA_NICE_H */
