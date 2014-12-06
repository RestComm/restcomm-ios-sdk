dnl Copyright (C) 2005-2006,2008 Nokia Corporation
dnl Contact: Kai Vehmanen <kai.vehmanen@nokia.com>
dnl Licensed under LGPL. See file COPYING.

dnl 
dnl ref: http://www.gnu.org/software/autoconf/manual/autoconf.info.gz
dnl
AC_PREREQ(2.57)

dnl information on the package
dnl ---------------------------

AC_INIT([sofsip-cli], [0.16])
AC_CONFIG_SRCDIR([src/ssc_sip.h])

AM_INIT_AUTOMAKE([foreign])
AM_MAINTAINER_MODE
AM_CONFIG_HEADER(config.h)

dnl checks for programs
dnl -------------------
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_CPP
AC_CHECK_PROG(ETAGS, etags, etags, echo)
AC_CHECK_TOOL(AR, ar, ar)
AC_CHECK_TOOL(LD, ld, ld)
AC_PROG_LIBTOOL

dnl checks for libraries
dnl --------------------

dnl lib: pthread
dnl oooooooooooo

AC_CHECK_LIB(pthread, pthread_create)

dnl headers: socket APIs
dnl oooooooooooooooooooo

AC_CHECK_HEADERS(netinet/in.h)
AC_CHECK_HEADERS(winsock2.h)
AC_CHECK_HEADERS(ws2tcpip.h)

dnl gen: media subsystems 
dnl ooooooooooooooooooooo

dnl lib: glib (optional)
dnl oooooooooooooooooooo

HAVE_GLIB=0
PKG_CHECK_MODULES(GLIB, glib-2.0 >= 2.12, [HAVE_GLIB_212=1], [HAVE_GLIB_212=0])

PKG_CHECK_MODULES(GLIB, glib-2.0 >= 2.6,[
    AC_DEFINE([HAVE_GOPTION], 1, [whether we have goptions])
    AC_DEFINE([HAVE_G_DEBUG], 1, [whether we have g_debug])
    HAVE_GLIB=1
],[
    PKG_CHECK_MODULES(GLIB, glib-2.0 >= 2.2, [
        AC_CONFIG_LIBOBJ_DIR(src)
        AC_LIBOBJ(replace_goption)
        HAVE_GLIB=1
    ],[	
        AC_MSG_ERROR([unable to build without at least glib-2.2 runtime and devel files])
        dnl AC_MSG_WARN([glib support will be disabled, also disables gstreamer/farsight media implementations])
    ])
])

AC_DEFINE_UNQUOTED([HAVE_GLIB], ${HAVE_GLIB}, [whether glib support is enabled])
dnl AM_CONDITIONAL([BUILD_GLIB_SRCS], [test x$HAVE_GLIB = x1])

PKG_CHECK_MODULES(GOBJECT2, gobject-2.0)
AC_SUBST(GOBJECT2_LIBS)
AC_SUBST(GOBJECT2_CFLAGS)
AC_SUBST(GOBJECT2_VERSION)

dnl note: even 'dummy' needs glib/gobject to work
MEDIA_IMPLS=" dummy"
X_MEDIA_IMPLS=""

dnl lib: gstreamer
dnl oooooooooooooo

GST_REQUIRED=0.10
GST_MAJORMINOR=0.10
PKG_CHECK_MODULES(GST, \
  gstreamer-$GST_MAJORMINOR >= $GST_REQUIRED,
  HAVE_GST=1, HAVE_GST=0)
AC_DEFINE_UNQUOTED([HAVE_GST], ${HAVE_GST}, [whether gstreamer support is enabled])

dnl Give a warning and exit if we don't have gstreamer
if test "x$HAVE_GST" = "x0"; then
  AC_MSG_WARN([NOTE: no gstreamer development packages found, disabling media support])
else
  MEDIA_IMPLS="${MEDIA_IMPLS} gst fsgst"
fi

dnl make GST_CFLAGS and GST_LIBS available
AC_SUBST(GST_CFLAGS)
AC_SUBST(GST_LIBS)

dnl make GST_MAJORMINOR available in Makefile.am
AC_SUBST(GST_MAJORMINOR)

dnl lib: farsight
dnl ooooooooooooo

AC_ARG_WITH([farsight],
    [AC_HELP_STRING([--with-farsight],
	[include Farsight media implementation])],
    [
        PKG_CHECK_MODULES(FARSIGHT, farsight-0.1 >= 0.1,
			  HAVE_FARSIGHT="1", HAVE_FARSIGHT="0")
	if test "x$HAVE_FARSIGHT" = "x1"; then
	   AC_SUBST(FARSIGHT_LIBS)
	   AC_SUBST(FARSIGHT_CFLAGS)
	   AC_DEFINE(HAVE_FARSIGHT, 1, [Farsight enabled])
	   if test "x${HAVE_GST}" = "x1" ; then
	      # note: not yet working
	      X_MEDIA_IMPLS="${X_MEDIA_IMPLS} farsight"
           fi
	fi
    ],
    [HAVE_FARSIGHT="0"])

dnl lib: sofia-sip-glib
dnl ooooooooooooooooooo

PKG_CHECK_MODULES(SOFIA_SIP_UA_GLIB, sofia-sip-ua-glib >= 1.12.3)
AC_SUBST(SOFIA_SIP_UA_GLIB_LIBS)
AC_SUBST(SOFIA_SIP_UA_GLIB_CFLAGS)
AC_SUBST(SOFIA_SIP_UA_GLIB_VERSION)

dnl lib: sofia-sip
dnl oooooooooooooo

PKG_CHECK_MODULES(SOFIA_SIP_UA, sofia-sip-ua >= 1.11.7work)
AC_SUBST(SOFIA_SIP_UA_LIBS)
AC_SUBST(SOFIA_SIP_UA_CFLAGS)
AC_SUBST(SOFIA_SIP_UA_VERSION)

dnl lib: nice (experimental, see README)
dnl oooooooooooooooooooooooooooooooooooo

PKG_CHECK_MODULES(NICE, nice >= 0.0.4, HAVE_LIBNICE="1", HAVE_LIBNICE="0")
if test "x$HAVE_LIBNICE" = "x1" ; then
  if test "x$HAVE_GLIB_212" = "x1" ; then
    AC_DEFINE(HAVE_LIBNICE, 1, [libnice enabled])
    X_MEDIA_IMPLS="${X_MEDIA_IMPLS} nice"
  else
    AC_MSG_WARN([glib 2.12 or newer required for nice support, disabling nice backend])
  fi
fi
AM_CONDITIONAL([BUILD_NICE_TESTER], [test x$HAVE_LIBNICE = x1])
AC_SUBST(NICE_LIBS)
AC_SUBST(NICE_CFLAGS)
AC_SUBST(NICE_VERSION)

dnl lib: libreadline
dnl oooooooooooooooo

dnl libreadline (see http://directory.fsf.org/readline.html)
AC_CHECK_HEADERS(readline/readline.h)
AC_CHECK_HEADERS(readline/history.h)
AC_CHECK_LIB(ncurses, tgetnum)
AC_CHECK_LIB(readline, readline)
if test $ac_cv_lib_readline_readline = yes -a $ac_cv_header_readline_readline_h = yes ; then
  use_readline=1
  echo "Using libreadline for console input."
else
  use_readline=0
  AC_WARN([NOTE: Not using libreadline for console input. Install libreadline and libreadline-dev to enable the feature.])
fi

dnl feature: default audio
dnl oooooooooooooooooooooo
AC_ARG_WITH([default-audio],
    [AC_HELP_STRING([--with-default-audio=FOO],
	[select which audio subsystem to use by default])],
    [def_audio="$withval"],
    [def_audio="ALSA"])
test -z "$def_audio" && def_audio="ALSA"
AC_DEFINE_UNQUOTED([SOFSIP_DEFAULT_AUDIO], "${def_audio}", [default audio subsystem to use])

dnl checks for types
dnl ----------------
dnl XXX

dnl checks for structures
dnl ---------------------
AC_HEADER_STDC
AC_CHECK_HEADERS(pthread.h)
AC_CHECK_HEADERS(stdint.h)
AC_CHECK_HEADERS(inttypes.h)
AC_CHECK_HEADERS(unistd.h sched.h)
AC_CHECK_HEADERS(sys/types.h sys/socket.h arpa/inet.h netinet/in.h)

dnl checks for typedefs, structures, and compiler characteristics.
dnl --------------------------------------------------------------
AC_C_CONST
AC_C_BIGENDIAN

dnl checks for system services
dnl --------------------------

AC_TRY_COMPILE(,
[
 #include <sched.h>
 pid_t pid;
 sched_getscheduler(pid);],
ac_cv_c_func_sched=yes, ac_cv_c_func_sched=no)
if test $ac_cv_c_func_sched = "yes"; then
AC_DEFINE([HAVE_SCHED_GETSCHEDULER], 1, [Define to 1 if sched.h has sched_getscheduler]) 
fi

dnl output
dnl ------

AC_CONFIG_FILES([
Makefile
doc/Makefile
src/Makefile
packages/Makefile
packages/sofsip-cli.spec
])

AC_OUTPUT

dnl summary
dnl ooooooo
echo -e "---------------------------------------------------------------"
echo "Configure results:"
echo -e "The following media implementations were enabled at build time:"
echo -e "\t- primary implementations...: ${MEDIA_IMPLS}"
echo -e "\t- test/experimental impl....: ${X_MEDIA_IMPLS:-<none>}"
echo -e "Following build time options were set:"
echo -e "\t- libreadline support.......:" ${use_readline:-0}
echo -e "---------------------------------------------------------------"
