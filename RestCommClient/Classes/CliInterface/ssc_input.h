/*
 * This file is part of the Sofia-SIP package
 *
 * Copyright (C) 2006 Nokia Corporation.
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

#ifndef HAVE_SSC_INPUT_H
#define HAVE_SSC_INPUT_H

/**
 * Callback for a new line of input.
 * The implementation is responsible for freeing the
 * char array given as parameter (malloc()'ed memery).
 */
typedef void (*ssc_input_handler_cb)(char *);

/**
 * Installs a callback for char input.
 *
 * @see ssc_input_read_char()
 */
void ssc_input_install_handler(const char* prompt, ssc_input_handler_cb func);

/**
 * Removes a previously installed input handler.
 */
void ssc_input_remove_handler(void);

/**
 * Refreshes the display contents.
 */
void ssc_input_refresh(void);

/**
 * Sets the current prompt to show.
 */
void ssc_input_set_prompt(const char* prompt);

/**
 * Function to call when input is detected by select().
 * If a line of input is available, the handler callback will
 * called.
 */
void ssc_input_read_char(int input_fd);

/**
 * Reads a string (at most 'size - 1' characters), and
 * stores them to 'str'. Read is performed as a blocking
 * operation.
 */
char *ssc_input_read_string(char *str, int size);

/**
 * Adds a string to history.
 */
void ssc_input_add_history(const char* entry);

/**
 * Clears the whole history.
 */
void ssc_input_clear_history(void);

/** 
 * Reset terminal state.
 */
void ssc_input_reset(void);

#endif /* HAVE_SSC_INPUT_H */

