/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2005-2006,2009 Nokia Corporation.
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

/**@NUA
 * 
 * @cfile sofsip_cli.c  Test application for Sofia-SIP User Agent,
 *  FarSight and gstreamer libraries. Based on nua_cli.c that
 *  was distributed with early 1.11 releases of the sofia-sip package.
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
#  if HAVE_GST
#  include <gst/gst.h>
#  endif
#endif /* HAVE_GLIB */

typedef struct cli_s cli_t;

#define SU_ROOT_MAGIC_T cli_t

#include "ssc_sip.h"
#include "ssc_input.h"

#include <sofia-sip/su_glib.h>

typedef su_wait_t cli_input_t;

#define SOFSIP_PROMPT "sofsip> "  

/**
 * Built time option to disable use of glib event loop
 * and use the Sofia event-loop instead. Disabling the
 * glib eventloop will also disable some functionality
 * such as the glib-based media subsystems.
 */
#define SOFSIP_USE_GLIB_EVENT_LOOP 1

struct cli_s {
  su_home_t     cli_home[1];	/**< Our memory home */
  void         *cli_main;      /**< Pointer to mainloop */
  su_root_t    *cli_root;       /**< Pointer to application root */

  cli_input_t   cli_input;	/**< Input structure */
  unsigned      cli_init : 1;	/**< True if input is initialized */
  unsigned      cli_prompt : 1;	/**< True if showing prompt */
  unsigned      cli_debug : 1;	/**< True if debugging is on */

  ssc_conf_t    cli_conf[1];  /**< Config settings for ssc_sip.h */

  ssc_t        *cli_ssc;        /**< Pointer to signaling subsystem */
};

static int sofsip_init(cli_t *cli, int ac, char *av[]);
static void sofsip_deinit(cli_t *cli);
/* static void sofsip_shutdown(cli_t *cli); */
static int sofsip_handle_input(cli_t *cli, su_wait_t *w, void *p);
static void sofsip_handle_input_cb(char *input);
static void sofsip_shutdown_cb(void);
static void sofsip_signal_handler(int signo);
static void sofsip_mainloop_create(cli_t *cli);
static void sofsip_mainloop_run(cli_t *cli);
static void sofsip_mainloop_destroy(cli_t *cli);
static void sofsip_auth_req_cb (ssc_t *ssc, const ssc_auth_item_t *authitem, void *pointer);
static void sofsip_event_cb (ssc_t *ssc, nua_event_t event, void *pointer);

static cli_t *global_cli_p = NULL;

int main(int ac, char *av[])
{
  cli_t cli[1] = {{{{sizeof(cli)}}}};
  int res = 0;
  global_cli_p = cli;

#ifndef _WIN32
  /* see: http://www.opengroup.org/onlinepubs/007908799/xsh/sigaction.html */
  struct sigaction sigact;
  memset(&sigact, 0, sizeof(sigact));
  sigact.sa_handler = sofsip_signal_handler;
  sigaction(SIGINT, &sigact, NULL); /* ctrl-c */
  sigaction(SIGABRT, &sigact, NULL);
  sigaction(SIGTERM, &sigact, NULL);
#endif

  /* step: initialize sofia su OS abstraction layer */
  su_init();
  su_home_init(cli->cli_home);

  /* step: initialize glib and gstreamer */
#if HAVE_GLIB
  g_type_init();
#if HAVE_GST
  {
    guint major, minor, micro, nano;
    gst_init (NULL, NULL);
    gst_version (&major, &minor, &micro, &nano);
    g_message ("This program is linked against GStreamer %d.%d.%d\n", major, minor, micro);
  }
#endif
#endif

  /* step: create a su event loop and connect it mainloop */
  sofsip_mainloop_create(cli);
  assert(cli->cli_root);

  /* Disable threading by command line switch? */
  su_root_threading(cli->cli_root, 0);

  /* step: parse command line arguments and initialize app event loop */
  res = sofsip_init(cli, ac, av);
  assert(res == 0);

  /* step: create ssc signaling and media subsystem instance */
  cli->cli_ssc = ssc_create(cli->cli_home, cli->cli_root, cli->cli_conf);

  if (res != -1 && cli->cli_ssc) {

    cli->cli_ssc->ssc_exit_cb = sofsip_shutdown_cb;
    cli->cli_ssc->ssc_auth_req_cb = sofsip_auth_req_cb;
    cli->cli_ssc->ssc_event_cb = sofsip_event_cb;
  
    ssc_input_install_handler(SOFSIP_PROMPT, sofsip_handle_input_cb);

    /* enter the main loop */
    sofsip_mainloop_run(cli);

    ssc_destroy(cli->cli_ssc), cli->cli_ssc = NULL;
  }
  
  sofsip_deinit(cli);
  ssc_input_clear_history();

  sofsip_mainloop_destroy(cli);
  su_home_deinit(cli->cli_home);
  su_deinit();

  return 0;
}

static void sofsip_mainloop_create(cli_t *cli)
{
#if SOFSIP_USE_GLIB_EVENT_LOOP
  GSource *gsource = NULL;
  GMainLoop *ptr = NULL;
  ptr = g_main_loop_new(NULL, FALSE);
  cli->cli_root = su_glib_root_create(cli);
  gsource = su_root_gsource(cli->cli_root);
  assert(gsource);
  g_source_attach(gsource, g_main_loop_get_context(ptr));
  cli->cli_main = (GMainLoop*)ptr;
#else
  cli->cli_root = su_root_create(cli);
#endif
}

static void sofsip_mainloop_run(cli_t *cli)
{
#if SOFSIP_USE_GLIB_EVENT_LOOP
    GMainLoop *ptr = (GMainLoop*)cli->cli_main;
    g_main_loop_run(ptr);
#else
    su_root_run(cli->cli_root);
#endif
}

static void sofsip_mainloop_destroy(cli_t *cli)
{
#if SOFSIP_USE_GLIB_EVENT_LOOP
  GSource *source = su_glib_root_gsource(cli->cli_root);
  g_source_unref(source);
#endif

  /* then the common part */
  su_root_destroy(cli->cli_root), cli->cli_root = NULL;

#if SOFSIP_USE_GLIB_EVENT_LOOP
  {
    GMainLoop *ptr = (GMainLoop*)cli->cli_main;
    g_main_loop_unref(ptr);
  }
#else
  /* no-op */
#endif
}

static void sofsip_shutdown_cb(void)
{
#if SOFSIP_USE_GLIB_EVENT_LOOP
  GMainLoop *ptr = (GMainLoop*)global_cli_p->cli_main;
  g_main_loop_quit(ptr);
#else
  su_root_break(global_cli_p->cli_root);
#endif
}

static void sofsip_signal_handler(int signo)
{
  fprintf(stderr, "\n\nWARNING: The program has received signal (%d) and will terminate.\n", signo);
  /* restore terminal to its original state */
  ssc_input_remove_handler();
  ssc_input_reset();
  exit(-1);
}

static void sofsip_help(cli_t *cli)
{
  printf("Synopsis:\n"
	 "\taddr <my-sip-address-uri> (set public address)\n"
	 "\tb (bye)\n"
	 "\tc (cancel)\n"
	 "\thold <to-sip-address-uri> (hold) \n"	 
	 "\ti <to-sip-address-uri> (invite) \n"
	 "\tk <[method:\"realm\":user:]password> (authenticate)\n"
	 "\tl (list operations)\n"
	 "\tm <to-sip-address-uri> (message)\n"
	 "\to <to-sip-address-uri> (options)\n"
	 "\tref <to-sip-address-uri> (refer)\n"	 
	 "\tr [sip-registrar-uri] (register)\n"
	 "\tu (unregister)\n"
	 "\tp [-] (publish) \n"
	 "\tup (unpublish)\n"
	 "\tset (print current settings)\n"
	 "\ts <to-sip-address-uri> (subscribe)\n"
	 "\tU (unsubscribe)\n"
	 "\tz (zap operation)\n"
	 "\tinfo\n"
	 "\te|q|x (exit)\n"
	 "\th|? (help)\n");
}

/** Add command line (standard input) to be waited. */
static int sofsip_init(cli_t *cli, int ac, char *av[])
{
  ssc_conf_t *conf = cli->cli_conf;
  int i;
  /* gboolean b = FALSE; */
  /* long, short, flags, arg, arg_data, desc, arg_desc */
  GOptionEntry options[] = {
    { "autoanswer", 'a', 0, G_OPTION_ARG_NONE, &conf->ssc_autoanswer, "Auto-answer to calls", NULL },
    { "register", 'R', 0, G_OPTION_ARG_NONE, &conf->ssc_register, "Register at startup", NULL },
    { "contact", 'c', 0, G_OPTION_ARG_STRING, &conf->ssc_contact, "SIP contact, local address to bind to (optional)", "SIP-URI" },
    { "media-addr", 'm', 0, G_OPTION_ARG_STRING, &conf->ssc_media_addr, "media address (optional)", "address"  },
    { "media-impl", 'i', 0, G_OPTION_ARG_STRING, &conf->ssc_media_impl, "media implementation to use", "dummy,gstreamer"  },
    { "registrar", 'r', 0, G_OPTION_ARG_STRING, &conf->ssc_registrar, "SIP registrar/server (optional)", "SIP-URI"  },
    { "proxy", 'p', 0, G_OPTION_ARG_STRING, &conf->ssc_proxy, "outbound proxy (optional)", "SIP-URI" },
    { "stun-server", 's', 0, G_OPTION_ARG_STRING, &conf->ssc_stun_server, "STUN server (optional)", "address"  },
    { NULL }
  };
  GOptionContext *context;
  GError *error = NULL;

  /* step: process environment variables */
  conf->ssc_aor = getenv("SOFSIP_ADDRESS");
  conf->ssc_proxy = getenv("SOFSIP_PROXY");
  conf->ssc_registrar = getenv("SOFSIP_REGISTRAR");
  conf->ssc_certdir = getenv("SOFSIP_CERTDIR");
  conf->ssc_stun_server = getenv("SOFSIP_STUN_SERVER");

  /* step: process command line arguments */
  context = g_option_context_new("- sofsip_cli usage");
  g_option_context_add_main_entries(context, options, "sofsip_cli");
#if HAVE_GST
  g_option_context_add_group (context, gst_init_get_option_group ());
#endif
  if (!g_option_context_parse(context, &ac, &av, &error)) {
      g_print ("option parsing failed: %s\n", error->message);
      exit (1);
  }
  g_option_context_free(context);

  for (i = 1; i < ac; i++) {
    if (av[i] && av[i][0] != '-') {
      cli->cli_conf->ssc_aor = av[i];
      break;
    }
  }

  su_wait_create(&cli->cli_input, 0, SU_WAIT_IN); 
  if (su_root_register(cli->cli_root, 
		       &cli->cli_input, 
		       sofsip_handle_input, 
		       NULL, 
		       0) == SOCKET_ERROR) {
    su_perror("su_root_register");
    return -1;
  }

  cli->cli_init = 1;

  return 0;
}

/** Unregister standard input. */
static void sofsip_deinit(cli_t *cli)
{
  if (cli->cli_init) {
    cli->cli_init = 0;
    if (su_root_unregister(cli->cli_root, 
			   &cli->cli_input, 
			   sofsip_handle_input, 
			   NULL) == SOCKET_ERROR) {
      su_perror("su_root_unregister");
    }

    su_wait_destroy(&cli->cli_input);

    ssc_input_remove_handler();

    /* g_main_loop_quit(cli->cli_gmain); */
  }
}

static int sofsip_handle_input(cli_t *cli, su_wait_t *w, void *p)
{
  /* note: sofsip_handle_input_cb is called if a full
   *       line has been read */
  ssc_input_read_char();

  return 0;
}

static void sofsip_handle_input_cb(char *input)
{
  char *rest, *command = input;
  cli_t *cli = global_cli_p;
  int n = command ? strlen(command) : 0;
  char msgbuf[160];

  /* see readline(2) */
  if (input == NULL) {
    ssc_shutdown(cli->cli_ssc);
    return;
  }

#define is_ws(c) ((c) != '\0' && strchr(" \t\r\n", (c)) != NULL)

  /* Skip whitespace at the end of line */
  while (n > 0 && is_ws(command[n - 1]))
    n--;
  command[n] = 0;
  /* Skip whitespace at the beginning of line */
  while (is_ws(*command))
    command++;

  ssc_input_add_history(command);

  /* Search first whitespace character */
  for (rest = command; *rest && !is_ws(*rest); rest++)
    ;
  /* Search non-whitespace and zero the whitespace */
  while (rest < command + n && is_ws(*rest))
    *rest++ = 0;
  if (rest >= command + n || !*rest)
    rest = NULL;

#define MATCH(c) (strcmp(command, c) == 0)
#define match(c) (strcasecmp(command, c) == 0)

  cli->cli_prompt = 0;

  if (match("a") || match("answer")) {
    ssc_answer(cli->cli_ssc, SIP_200_OK);
  }
  else if (match("addr")) {
    ssc_set_public_address(cli->cli_ssc, rest);
  }
  else if (match("b") || match("bye")) {
    ssc_bye(cli->cli_ssc);
  }
  else if (match("c") || match("cancel")) {
    ssc_cancel(cli->cli_ssc);
  }
  else if (MATCH("d")) {
    ssc_answer(cli->cli_ssc, SIP_480_TEMPORARILY_UNAVAILABLE);
  }
  else if (MATCH("D")) {
    ssc_answer(cli->cli_ssc, SIP_603_DECLINE); 
  }
  else if (match("h") || match("help")) {
    sofsip_help(cli);
  }
  else if (match("i") || match("invite")) {
    ssc_invite(cli->cli_ssc, rest);
  }
  else if (match("info")) {
    ssc_input_set_prompt("Enter INFO message> ");
    ssc_input_read_string(msgbuf, sizeof(msgbuf));
    ssc_info(cli->cli_ssc, rest, msgbuf);
  }
  else if (match("hold")) {
    ssc_hold(cli->cli_ssc, rest, 1);
  }   
  else if (match("unhold")) {
    ssc_hold(cli->cli_ssc, rest, 0);
  }   
  else if (match("k") || match("key")) {
    ssc_auth(cli->cli_ssc, rest);
  }
  else if (match("l") || match("list")) {
    ssc_list(cli->cli_ssc);
  }
  else if (match("m") || match("message")) {
    ssc_input_set_prompt("Enter message> ");
    ssc_input_read_string(msgbuf, sizeof(msgbuf));
    ssc_message(cli->cli_ssc, rest, msgbuf);
  }
  else if (match("set")) {
    ssc_print_settings(cli->cli_ssc);
  }
  else if (match("s") || match("subscribe")) {
    ssc_subscribe(cli->cli_ssc, rest);
  }
  else if (match("w") || match("watch")) {
    ssc_watch(cli->cli_ssc, rest);
  }
  else if (match("o") || match("options")) {
    ssc_options(cli->cli_ssc, rest);
  }
  else if (match("p") || match("publish")) {
    ssc_publish(cli->cli_ssc, rest);
  }
  else if (match("up") || match("unpublish")) {
    ssc_unpublish(cli->cli_ssc);
  }
  else if (match("r") || match("register")) {
    /* XXX: give AOR as param, and optionally a different registrar */
    ssc_register(cli->cli_ssc, rest);
  }
  else if (MATCH("u") || match("unregister")) {
    ssc_unregister(cli->cli_ssc, rest);
  }
  else if (match("ref") || match("refer")) {
    ssc_input_set_prompt("Enter refer_to address: ");
    ssc_input_read_string(msgbuf, sizeof(msgbuf));
    ssc_refer(cli->cli_ssc, rest, msgbuf);
  }
  else if (MATCH("U") || match("us") || match("unsubscribe")) {
    ssc_unsubscribe(cli->cli_ssc, rest);
  }
  else if (match("z") || match("zap")) {
    ssc_zap(cli->cli_ssc, rest);
  }
  else if (match("q") || match("x") || match("exit")) {
    ssc_shutdown(cli->cli_ssc);
  } 
  else if (command[strcspn(command, " \t\n\r=")] == '=') {
    /* Test assignment: foo=bar  */
    if ((rest = strchr(command, '='))) {
      cli->cli_prompt = 0;
      *rest++ = '\0';
      ssc_param(cli->cli_ssc, command, rest);
    }
  } 
  else if (match("?") || match("h") || match("help")) {
    sofsip_help(cli);
  }
  else {
    printf("Unknown command. Type \"help\" for help\n");
  }

  ssc_input_set_prompt(SOFSIP_PROMPT);
  free(input);
}

static void sofsip_auth_req_cb (ssc_t *ssc, const ssc_auth_item_t *authitem, void *pointer)
{
  printf("Please authenticate '%s' with the 'k' command (e.g. 'k password', or 'k [method:realm:username:]password')\n", 
	 authitem->ssc_scheme);
}

static void sofsip_event_cb (ssc_t *ssc, nua_event_t event, void *pointer)
{
  ssc_input_refresh();
}
