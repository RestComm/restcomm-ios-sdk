# Copyright (C) 2005-2006 Nokia Corporation
# Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
# Licensed under LGPL. See file COPYING.

AUTOMAKE_OPTIONS = foreign

INCLUDES = $(SOFIA_SIP_UA_CFLAGS) $(SOFIA_SIP_UA_GLIB_CFLAGS) $(GST_CFLAGS) $(GOBJECT2_CFLAGS) $(FARSIGHT_CFLAGS) $(NICE_CFLAGS)
LDADD = $(SOFIA_SIP_UA_LIBS) $(SOFIA_SIP_UA_GLIB_LIBS) $(GST_LIBS) $(GOBJECT2_LIBS) $(FARSIGHT_LIBS) $(LIBOBJS) $(NICE_LIBS)

noinst_LTLIBRARIES = libsofsip-cli-objects.la

noinst_HEADERS	= \
		ssc_media.h \
		ssc_media_gst.h \
		ssc_media_gst_utils.h \
		ssc_media_nice.h \
		nice_local.h \
		ssc_input.h \
		ssc_oper.h \
		ssc_sip.h \
		sdp_utils.h \
		farsight-netsocket.h \
		farsight-netsocket-stun.h \
		farsight-netsocket-utils.h 

# objects depending on glib
g_srcs = 	ssc_sip.c \
		ssc_media.c \
		ssc_media_gst_utils.c \
		ssc_media_gst.c \
		ssc_media_nice.c \
		nice_local.c \
		farsight-netsocket.c \
		farsight-netsocket-stun.c \
		farsight-netsocket-utils.c

if BUILD_NICE_TESTER
NICE_TESTER =   nice_tester
else
NICE_TESTER =   
endif

bin_PROGRAMS = 	sofsip_cli
noinst_PROGRAMS = \
		test_media \
		$(NICE_TESTER)

TESTS =		test_media

libsofsip_cli_objects_la_SOURCES = \
		ssc_oper.c \
		sdp_utils.c \
		$(g_srcs)

sofsip_cli_SOURCES = \
		sofsip_cli.c \
		ssc_input.c

sofsip_cli_LDADD = libsofsip-cli-objects.la ${LDADD}

EXTRA_sofsip_cli_SOURCES = \
		replace_goption.h replace_g_debug.h

nice_tester_LDADD = libsofsip-cli-objects.la ${LDADD}

test_media_SOURCES = test_media.c
test_media_LDADD = libsofsip-cli-objects.la ${LDADD}
