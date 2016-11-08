/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2006 Nokia Corporation.
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

/**@file ssc_input.c Helper routines for console input.
 * 
 * @author Kai Vehmanen <kai.vehmanen@nokia.com>
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if HAVE_UNISTD_H
#include <unistd.h>
#endif

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_LIBREADLINE
#ifdef HAVE_READLINE_READLINE_H
#include <readline/readline.h>
#endif
#ifdef HAVE_READLINE_HISTORY_H
#include <readline/history.h>
#endif
#endif

#include "ssc_input.h"
#include "common.h"
#include <unistd.h>

#if RL_READLINE_VERSION > 0x0400
#define USE_READLINE 1
#endif

static ssc_input_handler_cb ssc_input_handler_f;
static const char *ssc_input_prompt = "> ";

void ssc_input_install_handler(const char* prompt, ssc_input_handler_cb func)
{
#if USE_READLINE
  rl_callback_handler_install(prompt, func);
#else
  /* nop */
#endif
  ssc_input_handler_f = func;
}

void ssc_input_remove_handler(void)
{
#if USE_READLINE
  rl_callback_handler_remove();
#else
  /* nop */
#endif
  ssc_input_handler_f = NULL;
}

void ssc_input_set_prompt(const char* prompt)
{
#if USE_READLINE
  ssc_input_prompt = prompt;

  if (strcmp(rl_prompt, prompt)) {
    rl_set_prompt(prompt);
  }
#else
  int refresh = 0;

  if (strcmp(prompt, ssc_input_prompt)) 
    refresh = 1;

  ssc_input_prompt = prompt;
  
  if (refresh)
    ssc_input_refresh();
#endif
}

void ssc_input_read_char(int input_fd)
{
#if USE_READLINE
  if (ssc_input_handler_f)
    rl_callback_read_char();
#else
  char buf[65535];
  char * ptr = buf;
  ssize_t n;

  // important: there might be more than one commands in buf, but each command ends in '$'
  n = read(input_fd, buf, sizeof(buf) - 1);
  buf[n] = '\0';
    
  char * token;
  //int pos = 0;
  char delimiter = '$';
  if (strchr(buf, delimiter) == NULL) {
      printf("WARNING: Couldn't find delimiter char in the PIPE input -maybe buffer size is small??");
      exit(1);
  }
    
  while ((token = strsep(&ptr, "$")) != NULL) {
      if (n < 0) {
          perror("input: read");
      }
      else if (n > 0) {
          if (!strcmp(token, "")) {
              break;
          }
          char *tmpbuf;
          // not sure why n - 1 was used instead on n. Stange thing is that n - 1 worked in Linux but not in iOS
          ///buf[n - 1] = 0;
          //buf[n] = 0;
          tmpbuf = strdup((const char*)token);
          if (ssc_input_handler_f) {
              //printf("\n@@@@@@@@@ App >> Sofia: %s\n", tmpbuf);
              ssc_input_handler_f(tmpbuf);
          }
          ssc_input_refresh();
      }
  }


#endif
}

char *ssc_input_read_string(char *str, int size)
{
#if USE_READLINE
  char *input;

  /* disable readline callbacks */
  if (ssc_input_handler_f)
    rl_callback_handler_remove();

  rl_reset_line_state();

  /* read a string a feed to 'str' */
  input = readline(ssc_input_prompt);
  strncpy(str, input, size - 1);
  str[size - 1] = 0;

  /* free the copy malloc()'ed by readline */
  free(input);

  /* reinstall the func */
  if (ssc_input_handler_f)
    rl_callback_handler_install(ssc_input_prompt, ssc_input_handler_f);
  
  rl_redisplay();

  return str;
#else
  return fgets(str, size, stdin);
#endif
}

void ssc_input_refresh(void)
{
#if USE_READLINE
  rl_reset_line_state();
  rl_redisplay();
#else
  //RCLogDebug("%s", ssc_input_prompt);
  fflush(stdout);
#endif
}

void ssc_input_add_history(const char* entry)
{
#if USE_READLINE
  if (entry)
    add_history(entry);
#else
  /* nop */
#endif
}

void ssc_input_clear_history(void)
{
#if USE_READLINE
  clear_history ();
#else
  /* nop */
#endif
}

void ssc_input_reset(void)
{
#if USE_READLINE
  rl_reset_terminal(NULL);
#else
  /* nop */
#endif

}
