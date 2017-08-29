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

#include "common.h"
#import "RCUtilities.h"
#include "sofsip_cli.h"

typedef struct cli_s cli_t;

#define SU_ROOT_MAGIC_T cli_t

#include "ssc_sip.h"
#include "ssc_input.h"

typedef su_wait_t cli_input_t;

#define SOFSIP_PROMPT ""

/**
 * Built time option to disable use of glib event loop
 * and use the Sofia event-loop instead. Disabling the
 * glib eventloop will also disable some functionality
 * such as the glib-based media subsystems.
 */
#define SOFSIP_USE_GLIB_EVENT_LOOP 1

bool restartSignalling = false;
// let's reference nua & nta module global log facilities to be able to update their levels
extern su_log_t nua_log[];
extern su_log_t nta_log[];
extern su_log_t tport_log[];

extern su_log_t iptsec_log[];
extern su_log_t nea_log[];
extern su_log_t nth_client_log[];
extern su_log_t nth_server_log[];
//extern su_log_t soa_log[];
extern su_log_t sresolv_log[];
extern su_log_t stun_log[];

extern bool stackIsShuttingDown;

struct cli_s {
  su_home_t     cli_home[1];	/**< Our memory home */
  void         *cli_main;      /**< Pointer to mainloop */
  su_root_t    *cli_root;       /**< Pointer to application root */

  int           cli_input_fd;  // pipe input file descriptor for commands
  int           cli_output_fd;  // pipe input file descriptor for commands

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
//ssc_conf_t current_conf;
NSMutableDictionary * conf = [[NSMutableDictionary alloc] init];

@implementation SofiaConf

+ (void)dictionary:(NSMutableDictionary*)dictionary guardedSetString:(const char*)string forKey:(NSString*)key
{
    if (string) {
        [dictionary setObject:[NSString stringWithUTF8String:string] forKey:key];
    }
}

+ (void)dictionary:(NSMutableDictionary*)dictionary guardedSetObject:(NSObject*)object forKey:(NSString*)key
{
    if (object) {
        [dictionary setObject:object forKey:key];
    }
}

@end


int sofsip_loop(int ac, char *av[], const int input_fd, const int output_fd,
                const char * aor, const char * password, const char * registrar, const char * certificate_dir)
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

  cli->cli_input_fd = input_fd;
  cli->cli_output_fd = output_fd;

  [SofiaConf dictionary:conf guardedSetObject:[NSString stringWithUTF8String:aor] forKey:@"aor"];
  [SofiaConf dictionary:conf guardedSetObject:[NSString stringWithUTF8String:password] forKey:@"password"];
  [SofiaConf dictionary:conf guardedSetObject:[NSString stringWithUTF8String:registrar] forKey:@"registrar"];
  [SofiaConf dictionary:conf guardedSetObject:[NSString stringWithUTF8String:registrar] forKey:@"proxy"];
  [SofiaConf dictionary:conf guardedSetString:certificate_dir forKey:@"certificate-dir"];
  if (registrar != NULL) {
     [SofiaConf dictionary:conf guardedSetObject:@(YES) forKey:@"register"];
  }
  else {
     [SofiaConf dictionary:conf guardedSetObject:@(NO) forKey:@"register"];
  }
  
  /*
  current_conf.ssc_aor = aor;
  current_conf.ssc_password = password;
  // or registrar is proxy too
  current_conf.ssc_registrar = registrar;
  current_conf.ssc_proxy = registrar;
  current_conf.ssc_certdir = certificate_dir;
  if (registrar != NULL) {
      current_conf.ssc_register = true;
  }
  else {
      current_conf.ssc_register = false;
  }
  */

  while (1) {
        /* step: initialize sofia su OS abstraction layer */
        su_init();
        su_home_init(cli->cli_home);
        
        /* step: create a su event loop and connect it mainloop */
        sofsip_mainloop_create(cli);
        assert(cli->cli_root);
        
        /* Disable threading by command line switch? */
        su_root_threading(cli->cli_root, 0);
        
        /* step: parse command line arguments and initialize app event loop */
        res = sofsip_init(cli, ac, av);
        assert(res == 0);
      
        //cli->cli_conf[0] = current_conf;
      
        cli->cli_conf[0].ssc_aor = [[conf objectForKey:@"aor"] UTF8String];
        cli->cli_conf[0].ssc_password = [[conf objectForKey:@"password"] UTF8String];
        // or registrar is proxy too
        cli->cli_conf[0].ssc_registrar = [[conf objectForKey:@"registrar"] UTF8String];
        cli->cli_conf[0].ssc_proxy = [[conf objectForKey:@"proxy"] UTF8String];
        cli->cli_conf[0].ssc_certdir = [[conf objectForKey:@"certificate-dir"] UTF8String];
        cli->cli_conf[0].ssc_register = [[conf objectForKey:@"register"] boolValue];
      
        /* step: create ssc signaling and media subsystem instance */
        cli->cli_ssc = ssc_create(cli->cli_home, cli->cli_root, cli->cli_conf, cli->cli_input_fd, cli->cli_output_fd);
        
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
      
      if (!restartSignalling) {
          fprintf(stderr, "Shutting down signalling\n");
          break;
      }
      else {
          fprintf(stderr, "Restarting signalling after shutdown\n");
          restartSignalling = false;
      }
    }

  return 0;
}

static void sofsip_mainloop_create(cli_t *cli)
{
  cli->cli_root = su_root_create(cli);
}

static void sofsip_mainloop_run(cli_t *cli)
{
    su_root_run(cli->cli_root);
}

static void sofsip_mainloop_destroy(cli_t *cli)
{
  /* then the common part */
  su_root_destroy(cli->cli_root), cli->cli_root = NULL;
}

static void sofsip_shutdown_cb(void)
{
  su_root_break(global_cli_p->cli_root);
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
  RCLogDebug("Synopsis:\n"
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
    
  /* step: process environment variables */
  conf->ssc_aor = getenv("SOFSIP_ADDRESS");
  conf->ssc_proxy = getenv("SOFSIP_PROXY");
  conf->ssc_registrar = getenv("SOFSIP_REGISTRAR");
  conf->ssc_certdir = getenv("SOFSIP_CERTDIR");
  conf->ssc_stun_server = getenv("SOFSIP_STUN_SERVER");
  //conf->ssc_stun_server = "stun.l.google.com:19302";
  
  // enable logging of all SIP transport messages
  setenv("TPORT_LOG", "1", 1);
  // for some weird the logging of all SIP transport messages occurs in su_log_default, not tport_log. Hence, to be able to redirect those to our logging facilities
  // we use su_log_redirect(), that instead of doing the default logging for the su_log_default logger, calls the provided callback (for future reference, notice that I tried
  // passing tport_log instead of NULL as a first argument and got no tranport messages
  su_log_redirect(NULL, customSofiaLoggerCallback, NULL);
    
  for (i = 1; i < ac; i++) {
    if (av[i] && av[i][0] != '-') {
      cli->cli_conf->ssc_aor = av[i];
      break;
    }
  }
  // notice that in iOS we can't register STDIN; we get an error 'Invalid argument'
  // in su_root_register() below. Let's use a pipe instead for iOS core app <-> sofia sip communication
  su_wait_create(&cli->cli_input, cli->cli_input_fd, SU_WAIT_IN);
  if (su_root_register(cli->cli_root,
		       &cli->cli_input, 
		       sofsip_handle_input, 
		       NULL, 
		       0) == SOCKET_ERROR) {
    su_perror("su_root_register");
    return -1;
  }

  cli->cli_init = 1;

  // set default level to 9: to log everything
  su_log_set_level(nua_log, 9);
  su_log_set_level(nta_log, 9);
  su_log_set_level(nea_log, 9);
  su_log_set_level(nth_client_log, 9);
  su_log_set_level(nth_server_log, 9);
  su_log_set_level(sresolv_log, 9);
  su_log_set_level(stun_log, 9);
  su_log_set_level(tport_log, 9);
  
  
  // set default level to 2: non-critical errors
  //su_log_set_level(iptsec_log, 9);
  //su_log_set_level(nea_log, 2);
  //su_log_set_level(nth_client_log, 2);
  //su_log_set_level(nth_server_log, 2);
  //su_log_set_level(soa_log, 2);
  //su_log_set_level(stun_log, 2);

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
  }
}

static int sofsip_handle_input(cli_t *cli, su_wait_t *w, void *p)
{
  /* note: sofsip_handle_input_cb is called if a full
   *       line has been read */
  ssc_input_read_char(cli->cli_input_fd);

  return 0;
}

static void sofsip_handle_input_cb(char *input)
{
  //RCLogDebug("==== INPUT: %s", input);
  char *rest, *command = input;
  cli_t *cli = global_cli_p;
  int n = command ? (int)strlen(command) : 0;
  char msgbuf[160] = "";

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
  while (rest < command + n && is_ws(*rest)) {
    *rest = 0;
    rest += 1;
  }
  if (rest >= command + n || !*rest)
    rest = NULL;

#define MATCH(c) (strcmp(command, c) == 0)
#define match(c) (strcasecmp(command, c) == 0)

  cli->cli_prompt = 0;

  if (match("a") || match("answer")) {
      if (rest) {
          NSError * error;
          NSString * string = [NSString stringWithUTF8String:rest];
          NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
          
          ssc_answer(cli->cli_ssc, (char *)[[args objectForKey:@"sdp"] UTF8String], SIP_200_OK);
      }
  }
  else if (match("addr")) {
      if (rest) {
          NSError * error;
          NSString * string = [NSString stringWithUTF8String:rest];
          NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
          
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"aor"] forKey:@"aor"];
          ssc_set_public_address(cli->cli_ssc, [[args objectForKey:@"aor"] UTF8String]);
      }
  }
  else if (match("b") || match("bye")) {
    ssc_bye(cli->cli_ssc);
  }
  else if (match("c") || match("cancel")) {
    ssc_cancel(cli->cli_ssc);
  }
  else if (MATCH("d")) {
    ssc_answer(cli->cli_ssc, NULL, SIP_480_TEMPORARILY_UNAVAILABLE);
  }
  else if (MATCH("D")) {
    ssc_answer(cli->cli_ssc, NULL, SIP_603_DECLINE);
  }
  else if (match("h") || match("help")) {
    sofsip_help(cli);
  }
  else if (match("i") || match("invite")) {
      if (rest) {
          NSError * error;
          NSString * string = [NSString stringWithUTF8String:rest];
          NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
          
          // SIP headers might or might not be there
          char * sip_headers = NULL;
          if ([args objectForKey:@"sip-headers"]) {
              sip_headers = strdup([[args objectForKey:@"sip-headers"] UTF8String]);
          }
          
          ssc_invite(cli->cli_ssc, [[args objectForKey:@"destination"] UTF8String], [[args objectForKey:@"password"] UTF8String], [[args objectForKey:@"sdp"] UTF8String], sip_headers);
          
          if (sip_headers) {
              free(sip_headers);
          }
      }
  }
  else if (match("info")) {
    //ssc_input_set_prompt("Enter INFO message> ");
    //ssc_input_read_string(msgbuf, sizeof(msgbuf));
    ssc_info(cli->cli_ssc, rest);
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
      if (rest) {
          NSError * error;
          NSString * string = [NSString stringWithUTF8String:rest];
          NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
          
          if ([args objectForKey:@"sip-headers"]){
              ssc_message(cli->cli_ssc, [[args objectForKey:@"destination"] UTF8String], [[args objectForKey:@"password"] UTF8String], [[args objectForKey:@"message"] UTF8String], [[args objectForKey:@"sip-headers"] UTF8String]);
          }
          else {
              ssc_message(cli->cli_ssc, [[args objectForKey:@"destination"] UTF8String], [[args objectForKey:@"password"] UTF8String], [[args objectForKey:@"message"] UTF8String], NULL);
          }
      }
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
      if (rest) {
          NSError * error;
          NSString * string = [NSString stringWithUTF8String:rest];
          NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
          
          const char * aor = [[args objectForKey:@"aor"] UTF8String];
          const char * password = [[args objectForKey:@"password"] UTF8String];
          const char * registrar = [[args objectForKey:@"registrar"] UTF8String];
          
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"aor"] forKey:@"aor"];
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"password"] forKey:@"password"];
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"registrar"] forKey:@"registrar"];
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"registrar"] forKey:@"proxy"];
          if (registrar != NULL) {
              [SofiaConf dictionary:conf guardedSetObject:@(YES) forKey:@"register"];
          }
          else {
              [SofiaConf dictionary:conf guardedSetObject:@(NO) forKey:@"register"];
          }

          ssc_update(cli->cli_ssc, aor, password, registrar, false);
      }
      else {
          [conf removeObjectForKey:@"aor"];
          [conf removeObjectForKey:@"password"];
          [conf removeObjectForKey:@"registrar"];
          [conf removeObjectForKey:@"proxy"];
          [conf setObject:@(NO) forKey:@"register"];
          
          ssc_update(cli->cli_ssc, NULL, NULL, NULL, false);
      }
      //ssc_register(cli->cli_ssc, rest);
  }
  else if (MATCH("u") || match("unregister")) {
      if (rest) {
          NSError * error;
          NSString * string = [NSString stringWithUTF8String:rest];
          NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
          
          const char * aor = [[args objectForKey:@"aor"] UTF8String];
          const char * password = [[args objectForKey:@"password"] UTF8String];
          const char * registrar = [[args objectForKey:@"registrar"] UTF8String];
          
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"aor"] forKey:@"aor"];
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"password"] forKey:@"password"];
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"registrar"] forKey:@"registrar"];
          [SofiaConf dictionary:conf guardedSetObject:[args objectForKey:@"registrar"] forKey:@"proxy"];
          if (registrar != NULL) {
              [SofiaConf dictionary:conf guardedSetObject:@(YES) forKey:@"register"];
          }
          else {
              [SofiaConf dictionary:conf guardedSetObject:@(NO) forKey:@"register"];
          }

          ssc_update(cli->cli_ssc, aor, password, registrar, true);
      }
      else {
          [conf removeObjectForKey:@"aor"];
          [conf removeObjectForKey:@"password"];
          [conf removeObjectForKey:@"registrar"];
          [conf removeObjectForKey:@"proxy"];
          [conf setObject:@(NO) forKey:@"register"];

          ssc_update(cli->cli_ssc, NULL, NULL, NULL, true);
      }
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
  else if (match("qr")) {
      restartSignalling = true;
      ssc_shutdown(cli->cli_ssc);
  }
  else if (match("mr")) {
      // mark for restart if currently shutting down
      RCLogError("sofsip_handle_input_cb(), marking for restart, stackIsShuttingDown: %d", stackIsShuttingDown);
      if (stackIsShuttingDown) {
          restartSignalling = true;
          stackIsShuttingDown = false;
      }
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
    RCLogDebug("Unknown command. Type \"help\" for help\n");
  }

  ssc_input_set_prompt(SOFSIP_PROMPT);
  free(input);
}

static void sofsip_auth_req_cb (ssc_t *ssc, const ssc_auth_item_t *authitem, void *pointer)
{
  //RCLogDebug("Please authenticate '%s' with the 'k' command (e.g. 'k password', or 'k [method:realm:username:]password')\n", authitem->ssc_scheme);
}

static void sofsip_event_cb (ssc_t *ssc, nua_event_t event, void *pointer)
{
  ssc_input_refresh();
}
