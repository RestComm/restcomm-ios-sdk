/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005,2006,2007 Nokia Corporation.
 *
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

/**@NUA
 * 
 * @cfile nice_test_cli.c  Test application for libnice IETF ICE
 *  library. Based on sofsip_cli.c (part of the same package).
 *
 * @author Kai Vehmanen <kai.vehmanen@nokia.com>
 * @author Pekka Pessi <Pekka.Pessi@nokia.com>
 *
 * @date Created: Fri Sep  2 12:45:06 EEST 2005
 * $Date$
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

/* cannot be compiled without libnice */
#if HAVE_LIBNICE

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <signal.h>

/* note: glib is still a mandatory library - this is just to mark places
 *       of glib/gobject use in code */
#if HAVE_GLIB
#include <glib.h>
#include <glib-object.h>
#  if !HAVE_GOPTION
#  include "replace_goption.h"
#  endif
#  if !HAVE_G_DEBUG
#  include "replace_g_debug.h"
#  endif
#else
#error "GLIB required"
#endif /* HAVE_GLIB */

typedef struct nice_test_s nice_test_t;

#define SU_ROOT_MAGIC_T nice_test_t

#include "ssc_sip.h"
#include "ssc_media_nice.h"

#include <sofia-sip/su_glib.h>

typedef su_wait_t cli_input_t;

typedef enum {
  NT_STARTED = 0,
  NT_REGISTERED,
  NT_CALLING,
  NT_CALL_ACTIVE,
  NT_TERMINATED,
  NT_CLEANUP,
  NT_END
} NiceTestState;

struct nice_test_s {
  su_home_t     home[1];      /**< Our memory home */
  NiceTestState state;
  void         *main;         /**< Pointer to mainloop */
  su_root_t    *root;         /**< Pointer to application root */

  unsigned      init : 1;	/**< True if input is initialized */
  unsigned      prompt : 1;	/**< True if showing prompt */
  unsigned      debug : 1;	/**< True if debugging is on */

  ssc_conf_t    conf[1];      /**< Config settings for ssc_sip.h */

  ssc_t        *ssc;          /**< Pointer to signaling subsystem */

  const char   *test_uri;
  const char   *password;
};

static int nice_test_init(nice_test_t *cli, int ac, char *av[]);
static void nice_test_deinit(nice_test_t *cli);
static void nice_test_shutdown_cb(void);
static void nice_test_signal_handler(int signo);
static void nice_test_mainloop_create(nice_test_t *cli);
static void nice_test_mainloop_run(nice_test_t *cli);
static void nice_test_mainloop_destroy(nice_test_t *cli);

static void nice_test_auth_req_cb (ssc_t *ssc, const ssc_auth_item_t *authitem, void *pointer);
static void nice_test_call_state_cb(ssc_t *ssc, ssc_oper_t *oper, int ss_state, void *context);
static void nice_test_media_state_cb(ssc_t *ssc, ssc_oper_t *oper, enum SscMediaState state, void *context);
static void nice_test_registration_cb(ssc_t *ssc, int registered, void *context);

static nice_test_t *global_nice_test_p = NULL;

static void priv_state_to (nice_test_t *nice_test, int state, const char* phrase)
{
  if (state != nice_test->state) {
    nice_test->state = state;
    printf ("NICE test state to %s\n", phrase);
  }
}

static gboolean timer_cb (gpointer pointer)
{
  nice_test_t *nice_test = pointer;
  printf ("NICE test timeout, terminating test run.\n");
  priv_state_to (nice_test, NT_END, "END");
  g_main_loop_quit(nice_test->main);
  return FALSE;
}

int main(int ac, char *av[])
{
  nice_test_t nice_test[1] = {{{{sizeof(nice_test)}}}};
  int res = 0;
  global_nice_test_p = nice_test;
  guint timer_id = 0;

#ifndef _WIN32
  /* see: http://www.opengroup.org/onlinepubs/007908799/xsh/sigaction.html */
  struct sigaction sigact;
  memset(&sigact, 0, sizeof(sigact));
  sigact.sa_handler = nice_test_signal_handler;
  sigaction(SIGINT, &sigact, NULL); /* ctrl-c */
  sigaction(SIGABRT, &sigact, NULL);
  sigaction(SIGTERM, &sigact, NULL);
#endif

  /* step: initialize sofia su OS abstraction layer */
  su_init();
  su_home_init(nice_test->home);

  /* step: initialize glib and gstreamer */
#if HAVE_GLIB
  g_type_init();
#endif

  /* step: create a su event loop and connect it mainloop */
  nice_test_mainloop_create(nice_test);
  assert(nice_test->root);

  /* Disable threading by command line switch? */
  su_root_threading(nice_test->root, 0);

  /* step: parse command line arguments and initialize app event loop */
  res = nice_test_init(nice_test, ac, av);
  assert(res == 0);

  if (nice_test->test_uri == NULL ||
      nice_test->conf->ssc_aor == NULL) {
    fprintf (stderr, "usage: nice_testers <sip-aor> <uri-to-call> [<reg.password>]\n");
    res = -1;
  }

  if (res == 0)
    /* step: create ssc signaling and media subsystem instance */
    nice_test->ssc = ssc_create(nice_test->home, nice_test->root, nice_test->conf);

  if (res != -1 && nice_test->ssc) {

    ssc_t *ssc = nice_test->ssc;

    timer_id = g_timeout_add (30000, timer_cb, nice_test);

    ssc_set_public_address(ssc, nice_test->conf->ssc_aor);

    ssc->ssc_cb_context = nice_test;
    ssc->ssc_exit_cb = nice_test_shutdown_cb;
    ssc->ssc_auth_req_cb = nice_test_auth_req_cb;
    ssc->ssc_call_state_cb = nice_test_call_state_cb;
    ssc->ssc_media_state_cb = nice_test_media_state_cb;
    ssc->ssc_registration_cb = nice_test_registration_cb;

    res = -1;

    /* step: register to network */
    ssc_register(ssc, NULL);

    /* step: run mainloop until registration is completed (or failed) */
    nice_test_mainloop_run(nice_test);

    if (nice_test->state == NT_REGISTERED) {
      /* step: make the test call */
      ssc_invite (ssc, nice_test->test_uri);

      /* step: run mainloop until call completed */
      nice_test_mainloop_run(nice_test);

      if (nice_test->state == NT_CALL_ACTIVE) {
	SscMediaNice *nice_media = (SscMediaNice*)ssc->ssc_media;
	/* note: mark test as succesful only if ICE connectivity
	 *       checks have succeeded */
	g_debug ("Test packets sent %u", nice_media->nice_test_packets_sent);
	if (nice_media &&
	    /*nice_media->nice_test_packets_received == 2 && */
	    nice_media->nice_test_packets_received == 2)
	  res = 0;
      }

      priv_state_to (nice_test, NT_CLEANUP, "CLEANUP");

      /* step: hang up the establish call */
      ssc_bye (ssc);

      /* step: unregister */
      ssc_unregister (ssc, NULL);
    
      /* step: run mainloop until cleanup completed */
      nice_test_mainloop_run(nice_test);
    }

    ssc_destroy(nice_test->ssc), nice_test->ssc = NULL;
  }

  if (timer_id)
    g_source_remove (timer_id);
  
  nice_test_deinit(nice_test);
  nice_test_mainloop_destroy(nice_test);
  su_home_deinit(nice_test->home);
  su_deinit();

  printf ("\n\ntest result: %s.\n", res ? "FAILURE" : "SUCCESS");

  return res;
}

static void nice_test_mainloop_create(nice_test_t *nice_test)
{
  GSource *gsource = NULL;
  GMainLoop *ptr = NULL;
  ptr = g_main_loop_new(NULL, FALSE);
  nice_test->root = su_glib_root_create(nice_test);
  gsource = su_root_gsource(nice_test->root);
  assert(gsource);
  g_source_attach(gsource, g_main_loop_get_context(ptr));
  nice_test->main = (GMainLoop*)ptr;
}

static void nice_test_mainloop_run(nice_test_t *nice_test)
{
    GMainLoop *ptr = (GMainLoop*)nice_test->main;
    g_main_loop_run(ptr);
}

static void nice_test_mainloop_destroy(nice_test_t *nice_test)
{
  GSource *source = su_glib_root_gsource(nice_test->root);

  /* then the common part */
  su_root_destroy(nice_test->root), nice_test->root = NULL;

  g_source_unref(source);

  {
    GMainLoop *ptr = (GMainLoop*)nice_test->main;
    g_main_loop_unref(ptr);
  }
}

static void nice_test_shutdown_cb(void)
{
  GMainLoop *ptr = (GMainLoop*)global_nice_test_p->main;
  g_main_loop_quit(ptr);
}

static void nice_test_signal_handler(int signo)
{
  fprintf(stderr, "\n\nWARNING: The program has received signal (%d) and will terminate.\n", signo);
  /* restore terminal to its original state */
  exit(-1);
}

/** Add command line (standard input) to be waited. */
static int nice_test_init(nice_test_t *nice_test, int ac, char *av[])
{
  ssc_conf_t *conf = nice_test->conf;
  int i, aor_found, touri_found;

  /* gboolean b = FALSE; */
  /* long, short, flags, arg, arg_data, desc, arg_desc */
  GOptionEntry options[] = {
    { "autoanswer", 'a', 0, G_OPTION_ARG_NONE, &conf->ssc_autoanswer, "Auto-answer to calls", NULL },
    { "contact", 'c', 0, G_OPTION_ARG_STRING, &conf->ssc_contact, "SIP contact, local address to bind to (optional)", "SIP-URI" },
    { "media-addr", 'm', 0, G_OPTION_ARG_STRING, &conf->ssc_media_addr, "media address (optional)", "address"  },
    { "proxy", 'p', 0, G_OPTION_ARG_STRING, &conf->ssc_proxy, "outbound proxy (optional)", "SIP-URI" },
    { "stun-server", 's', 0, G_OPTION_ARG_STRING, &conf->ssc_stun_server, "STUN server (optional)", "address"  },
    { NULL }
  };
  GOptionContext *context;

  /* step: process environment variables */
  conf->ssc_aor = getenv("NICE_TEST_ADDRESS");
  conf->ssc_proxy = getenv("NICE_TEST_PROXY");
  conf->ssc_registrar = getenv("NICE_TEST_REGISTRAR");
  conf->ssc_certdir = getenv("NICE_TEST_ADDRESS");
  conf->ssc_stun_server = getenv("NICE_TEST_STUN_SERVER");
  conf->ssc_media_impl = "nice";

  /* step: process command line arguments */
  context = g_option_context_new("- nice_test_cli usage");
  g_option_context_add_main_entries(context, options, "nice_test_cli");
  g_option_context_parse(context, &ac, &av, NULL);
  g_option_context_free(context);

  aor_found = 0;
  touri_found = 0;
  for (i = 1; i < ac; i++) {
    if (av[i] && av[i][0] != '-') {
      if (!aor_found) {
	nice_test->conf->ssc_aor = av[i];
	aor_found = 1;
      }
      else if (!touri_found) {
	/* SIP URI to call to */
	nice_test->test_uri = av[i];
	touri_found = 1;
      }
      else {
	nice_test->password = av[i];
	break;
      }
    }
  }

  nice_test->init = 1;

  return 0;
}

/** Unregister standard input. */
static void nice_test_deinit(nice_test_t *nice_test)
{
  if (nice_test->init) {
    nice_test->init = 0;
    /* g_main_loop_quit(nice_test->gmain); */
  }
}

static void nice_test_auth_req_cb (ssc_t *ssc, const ssc_auth_item_t *authitem, void *pointer)
{
  nice_test_t *nice_test = (nice_test_t *)pointer;

  printf ("Providing authentication credentials to realm %s (username %s).", 
	   authitem->ssc_realm, authitem->ssc_username);
  ssc_auth (ssc, nice_test->password);
}

static void nice_test_media_state_cb(ssc_t *ssc, ssc_oper_t *oper, enum SscMediaState state, void *context)
{
  nice_test_t *nice_test = (nice_test_t *)context;

  printf ("Media state changed to %u.\n", (int)state);

  if (state == sm_active) {
    priv_state_to (nice_test, NT_CALL_ACTIVE, "CALL_ACTIVE");
    g_main_loop_quit(nice_test->main);
  }

}

static void nice_test_call_state_cb(ssc_t *ssc, ssc_oper_t *oper, int ss_state, void *context)
{
  nice_test_t *nice_test = (nice_test_t *)context;
  
  printf ("Call state changed to %u.\n", 
	  ss_state);

  if (ss_state == nua_callstate_terminated) {
    priv_state_to (nice_test, NT_TERMINATED, "TERMINATED");
    g_main_loop_quit(nice_test->main);
  }
}

static void nice_test_registration_cb(ssc_t *ssc, int registered, void *context)
{
  nice_test_t *nice_test = (nice_test_t *)context;

  printf ("%s: registration status %d (test status %d).\n", G_STRFUNC, registered, nice_test->state);

  if (registered &&
      nice_test->state == NT_STARTED) {
    priv_state_to (nice_test, NT_REGISTERED, "REGISTERED");
    g_main_loop_quit(nice_test->main);
  }
  else if (!registered &&
	   nice_test->state == NT_CLEANUP) {
    priv_state_to (nice_test, NT_END, "END");
    g_main_loop_quit(nice_test->main);
  }
}

#endif /* HAVE_LIBNICE */

