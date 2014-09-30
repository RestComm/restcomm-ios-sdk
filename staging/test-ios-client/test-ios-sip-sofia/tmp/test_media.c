/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005-2006,2009 Corporation.
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

/**@file test_media.c Test app for ssc_media*.h
 * 
 * @author Kai Vehmanen <kai.vehmanen@nokia.com>
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#define _GNU_SOURCE /* for str*() */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(HAVE_SCHED_H) && defined(HAVE_SCHED_GETSCHEDULER)
#define TWEAK_SCHEDULER 1
#include <sched.h>
#endif

#include <glib.h>
#include <sofia-sip/su_source.h>

#if HAVE_GST
#include "ssc_media_gst.h"
#endif
#include "ssc_media.h"

#if !HAVE_G_DEBUG
#include "replace_g_debug.h"
#endif

static int update_port(char **sdp_str, int port);
static int update_ip4addr(char **sdp_str, const char *addr);

int main(int argc, char *argv[])
{
  int res = 0;
  char *local_sdp = NULL, *remote_sdp = NULL;
  GMainLoop *gmain;
  GSource *gsource;
  SscMedia *ssc_media;
  su_root_t *root;

#if TWEAK_SCHEDULER
  struct sched_param spolicy;
#endif

#if HAVE_GST
  gst_init (&argc, &argv);
#endif
  g_type_init();

  /* create a su event loop and connect it to glib */
  gmain = g_main_loop_new(NULL, FALSE);
  root = su_root_source_create(gmain);
  g_assert(root);
  gsource = su_root_gsource(root);
  g_assert(gsource);


#if TWEAK_SCHEDULER
  spolicy.sched_priority = 10;
  g_debug("scheduler from=%d", (int)sched_getscheduler(0));
  sched_setscheduler(0, SCHED_RR, &spolicy);
  g_debug("scheduler to=%d", (int)sched_getscheduler(0));
#endif

  g_source_attach(gsource, g_main_loop_get_context(gmain));

#if HAVE_GST
  g_message("Selecting media implementation: Gstreamer-RTP");
  ssc_media = g_object_new (SSC_MEDIA_GST_TYPE, NULL);
#else
  g_message("Selecting media implementation: Dummy");
  ssc_media = g_object_new (SSC_MEDIA_TYPE, NULL);
#endif

  g_debug("%s:%d", __func__, __LINE__);

  if (!ssc_media) {
    g_message("Unable to initialize media subsystem, exiting..");
    return 0;
  }

#if 0
  ssc_media_set_pref_stun(media, 0);
#endif
  
  ssc_media_static_capabilities(ssc_media, &local_sdp);

  /* create remote SDP based on local SDP */
  remote_sdp = strdup(local_sdp);
  
  if (update_port(&local_sdp, 5400) == 0 && 
      update_ip4addr(&local_sdp, "127.0.0.1") == 0 &&
      update_port(&remote_sdp, 5400) == 0 && 
      update_ip4addr(&remote_sdp, "127.0.0.1") == 0) {
    time_t now, until;
    time(&now);
    until = now + 10;

    g_message("Local SDP used for testing:\n%s\n", local_sdp);
    g_message("Remote SDP used for testing:\n%s\n", remote_sdp);

    g_object_set(G_OBJECT(ssc_media), "localsdp", local_sdp, NULL);
    g_object_set(G_OBJECT(ssc_media), "remotesdp", remote_sdp, NULL);

    /* activate is synchronous when not using STUN */
    ssc_media_activate(SSC_MEDIA(ssc_media));

    if (ssc_media_is_active(SSC_MEDIA(ssc_media))) {
      g_message("Phase 1 - running for 10secs...");
      while(now < until) {
	g_main_context_iteration(NULL, FALSE);
	time(&now);
      }
      ssc_media_deactivate(SSC_MEDIA(ssc_media));
    }

    /* step: second run */
    ssc_media_activate(SSC_MEDIA(ssc_media));

    if (ssc_media_is_active(SSC_MEDIA(ssc_media))) {
      g_message("Phase 2 - running for another 10secs...");
      time(&now);
      until = now + 10;
      while(now < until) {
	g_main_context_iteration(NULL, FALSE);
	time(&now);
      }
      ssc_media_deactivate(SSC_MEDIA(ssc_media));
    }
  }

  g_object_unref(ssc_media);

#if TWEAK_SCHEDULER
  spolicy.sched_priority = 0;
  g_debug("scheduler from=%d", (int)sched_getscheduler(0));
  sched_setscheduler(0, SCHED_OTHER, &spolicy);
  g_debug("scheduler to=%d", (int)sched_getscheduler(0));
#endif

  free(remote_sdp);
  su_root_destroy(root);
  g_main_loop_unref(gmain);

  return res;
}

static int update_port(char **sdp_str, int port)
{
  char *l_sdp = *sdp_str;
  int l_len = strlen(l_sdp);
  sdp_parser_t *parser;
  sdp_session_t *sdp;
  int result = -1;
 
  parser = sdp_parse(NULL, l_sdp, l_len, sdp_f_config);
  sdp = sdp_session(parser);
  if (sdp != NULL) {
    sdp_printer_t *printer;
    const char* pr_error;

    sdp->sdp_media->m_port = port;

    free(*sdp_str), *sdp_str = (char*)malloc(l_len * 2);
    
    printer = sdp_print(NULL, sdp, *sdp_str, l_len * 2, 0);
    pr_error = sdp_printing_error(printer);
    if (pr_error == NULL) {
      result = 0;
    }
    else {
      g_message("SDP encoding error: %s.\n", pr_error);
    }
    sdp_printer_free(printer);
  }
  
  return result;
}

static int update_ip4addr(char **sdp_str, const char *addr)
{
  char *l_sdp = *sdp_str;
  int l_len = strlen(*sdp_str);
  sdp_parser_t *parser;
  sdp_session_t *sdp;
  sdp_media_t *media;
  sdp_printer_t *printer;
  su_home_t *home;
  int result = -1;
  const char *pr_error;
 
  parser = sdp_parse(NULL, l_sdp, strlen(l_sdp), sdp_f_config);
  sdp = sdp_session(parser);
  media = (sdp != NULL ? sdp->sdp_media : NULL);
  home = sdp_parser_home(parser);

  if (sdp) {
    sdp_connection_t* conn = sdp->sdp_connection;
    if (!conn) {
      conn = su_salloc(home, sizeof(sdp_connection_t));
      conn->c_addrtype = sdp_addr_ip4;
      sdp->sdp_connection = conn;
    }
    /* we have to modify the const field using the
     * SDP parser su_home */
    su_free(home, (char*)conn->c_address);
    conn->c_address = su_strdup(home, addr);
  }

  for(; media; media = media->m_next) {
    sdp_connection_t* conn = sdp_media_connections(media);

    if (!conn) {
      conn = su_salloc(home, sizeof(sdp_connection_t));
      conn->c_addrtype = sdp_addr_ip4;
      media->m_connections = conn;
    }

    for(; conn; conn = conn->c_next) {
      if (conn->c_addrtype == sdp_addr_ip4) {
	/* we have to modify the const field using the
	 * SDP parser su_home */
	su_free(home, (char*)conn->c_address);
	conn->c_address = su_strdup(home, addr);
      }
    }
  }

  free(*sdp_str), *sdp_str = (char*)malloc(l_len * 2);
  printer = sdp_print(NULL, sdp, *sdp_str, l_len * 2, 0);

  pr_error = sdp_printing_error(printer);
  if (pr_error == NULL) {
    result = 0;
  }
  else {
    g_message("SDP encoding error: %s.\n", pr_error);
  }
  sdp_printer_free(printer);

 
  return result;
}
