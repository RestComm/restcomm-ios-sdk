//
//  sofia-ua-wrapper.c
//  test-sip1
//
//  Created by Antonis Tsakiridis on 8/30/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

/*
#include <stdio.h>

int printSum(int a, int b)
{
    printf("Sum is: %d", a + b);
    return a + b;
}
*/
#include <stdio.h>
#include "sofia-ua-wrapper.h"

typedef struct client_s client_t;

#define NUA_MAGIC_T client_t

#include <sofia-sip/nua.h>

struct client_s {
	su_home_t     home[1];	/**< Our memory home */
	su_root_t    *root;       /**< Pointer to application root */
	nua_t        *nua;        /**< Pointer to NUA object */
};

void send_message (nua_t *nua, const char * msg, const char * to);  

void event_callback(nua_event_t   event,
		int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[]);

static void app_i_invite (int status,
		char const *phrase,
		nua_t * nua,
		nua_magic_t * magic,
		nua_handle_t * nh,
		nua_hmagic_t * hmagic,
		sip_t const *sip,
		tagi_t tags[]);

void app_i_active(int           status,
                   char const   *phrase,
                   nua_t        *nua,
                   nua_magic_t  *magic,
                   nua_handle_t *nh,
                   nua_hmagic_t *hmagic,
                   sip_t const  *sip,
                   tagi_t        tags[]);

void app_i_message(int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[]);

void app_r_shutdown(int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[]);

int sofia_loop(const char * msg)
{
	//su_root_t *root;
	//nua_t *nua;

	/* Initialize Sofia-SIP library and create event loop */

	/* Application context structure */
	client_t appl[1] = {{{{sizeof(appl)}}}};

	su_init ();

	/* initialize memory handling */
	su_home_init(appl->home);

	/* initialize root object */
	appl->root = su_root_create(appl);
	//root = su_root_create (NULL);

	/* Create a user agent instance. Caller and callee should bind to different
	 * address to avoid conflicts. The stack will call the 'event_callback()'
	 * callback when events such as succesful registration to network,
	 * an incoming call, etc, occur.
	 */
	appl->nua = nua_create(appl->root, /* Event loop */
			event_callback, /* Callback for processing events */
			appl, /* Additional data to pass to callback */
#ifdef CALLER
			NUTAG_URL("sip:0.0.0.0:5062"), /* Address to bind to */
#else
			NUTAG_URL("sip:0.0.0.0:5060"),
#endif
			TAG_END()); /* Last tag should always finish the sequence */

#ifdef CALLER
	printf("Sending message");
	send_message (appl->nua, msg, "sip:test@192.168.2.30:5060");
#endif
	/* Run event loop */
	su_root_run (appl->root);

	/* Destroy allocated resources */
	nua_destroy (appl->nua);
	su_root_destroy (appl->root);
	su_deinit ();

	return 0;
}

/* This callback will be called by SIP stack to
 * process incoming events
 */
void event_callback(nua_event_t   event,
		int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[])
{
	printf ("-- Received event %s status %d %s\n",
			nua_event_name (event), status, phrase);

	switch (event) {
		case nua_i_invite:
			printf ("-- Incoming Call\n");

			app_i_invite(status, phrase, nua, magic, nh, hmagic, sip, tags);
			break;

		case nua_r_invite:
			//app_r_invite(status, phrase, nua, magic, nh, hmagic, sip, tags);
			break;

		case nua_i_active:
			app_i_active(status, phrase, nua, magic, nh, hmagic, sip, tags);
			break;

		case nua_i_message:
			printf ("-- Incoming Message\n");
			app_i_message(status, phrase, nua, magic, nh, hmagic, sip, tags);
			break;

		case nua_r_message:
			printf ("-- Response Message\n");
			//app_i_message(status, phrase, nua, magic, nh, hmagic, sip, tags);
			break;

		case nua_r_shutdown:
			app_r_shutdown(status, phrase, nua, magic, nh, hmagic, sip, tags);
			break;

		default:
			/* unknown event -> print out error message */
			if (status > 100) {
				printf("-- Unknown event %d: %03d %s\n",
						event,
						status,
						phrase);
			}
			else {
				printf("-- Unknown event %d\n", event);
			}
			//tl_print(stdout, "", tags);
			break;
	}
}

// received invite
static void app_i_invite (int status,
		char const *phrase,
		nua_t * nua,
		nua_magic_t * magic,
		nua_handle_t * nh,
		nua_hmagic_t * hmagic,
		sip_t const *sip,
		tagi_t tags[])
{
	// TODO: uncomment and fix it
	/*
	   nua_respond(nh,
	   200,
	   "OK",
	   SOA_USER_SDP(magic->sdp),
	   TAG_END());
	 */
	nua_respond (nh, 200, "OK", TAG_END ());
}

void app_i_active(int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[])
{
	printf("-- Call Active\n");

} /* app_i_active */

void app_i_message(int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[])
{
	printf("received MESSAGE: %03d %s\n", status, phrase);

	/*
	char uri[256] = "";
	snprintf(uri, sizeof(uri) - 1, URL_PRINT_FORMAT,
			URL_PRINT_ARGS(sip->sip_from->a_url));
	*/

	printf("From: %s%s" URL_PRINT_FORMAT "\n",
			sip->sip_from->a_display ? sip->sip_from->a_display : "",
			sip->sip_from->a_display ? " " : "",
			URL_PRINT_ARGS(sip->sip_from->a_url));

	if (sip->sip_subject) {
		printf("Subject: %s\n", sip->sip_subject->g_value);
	}

	if (sip->sip_payload) {
		fwrite(sip->sip_payload->pl_data, sip->sip_payload->pl_len, 1, stdout);
		fputs("\n", stdout);
	}

#ifndef CALLER
	// want just the callee to repond
	send_message (nua, "Hello caller...", "sip:test@127.0.0.1:5062");  
	//send_message (nua, "Hello caller...", sip->sip_from->a_display);  
#endif

#ifdef CALLER
	// this was supposed to work, but instead I got a crash, so I used the nua_shutdown()
	//su_root_break(magic->root);
	nua_shutdown(nua);
#endif
} /* app_i_message */

void app_r_shutdown(int           status,
		char const   *phrase,
		nua_t        *nua,
		nua_magic_t  *magic,
		nua_handle_t *nh,
		nua_hmagic_t *hmagic,
		sip_t const  *sip,
		tagi_t        tags[])
{
	printf("shutdown: %d %s\n", status, phrase);

	if (status < 200) {
		/* shutdown in progress -> return */
		return;
	}

	/* end the event loop. su_root_run() will return */
	su_root_break(magic->root);

} /* app_r_shutdown */

/* Create a communication handle, send MESSAGE with it and destroy it */  
void send_message (nua_t *nua, const char * msg, const char * to)  
{  
	nua_handle_t *handle;  

	//handle = nua_handle(nua, NULL, SIPTAG_TO_STR("sip:test@127.0.0.1:5060"), TAG_END());  
	handle = nua_handle(nua, NULL, SIPTAG_TO_STR(to), TAG_END());  

	nua_message(handle,  
			SIPTAG_CONTENT_TYPE_STR("text/plain"),
			//SIPTAG_PAYLOAD_STR("Hello callee!!!"),
			SIPTAG_PAYLOAD_STR(msg),
			TAG_END());  

	nua_handle_destroy (handle);  
}  
