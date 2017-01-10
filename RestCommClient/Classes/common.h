/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2015, Telestax Inc and individual contributors
 * by the @authors tag.
 *
 * This program is free software: you can redistribute it and/or modify
 * under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 * For questions related to commercial use licensing, please contact sales@telestax.com.
 *
 */

#ifndef RestCommClient_common_h
#define RestCommClient_common_h

#include <asl.h>
#include <stdio.h>
#include <unistd.h>
#include <libgen.h>

#define LOG_BUFFER_SIZE 65536
#define SIP_USER_AGENT "TelScale Restcomm iOS Client #BASE_VERSION-#VERSION_SUFFIX+#BUILD"
#define ENABLE_LOGGING 1
// iOS version checks
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


// simple extern "C" doesn't work in all cases, need to differentiate:
#if !defined(__cplusplus)
#define ExternC extern
#else
#define ExternC extern "C"
#endif

ExternC void customSofiaLoggerCallback(void *stream, char const *fmt, va_list ap);
ExternC void initializeLogging(void);
ExternC void finalizeLogging(void);
ExternC void setLogLevel(int level);

#define RC_MAKE_LOG_FUNCTION_DECL(LEVEL, NAME) \
ExternC void NAME (const char * filename, const int linenumber, const char *format, ...);

// Generate a function declaration for each level
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_EMERG, _RCLogEmerg)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_ALERT, _RCLogAlert)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_CRIT, _RCLogCrit)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_ERR, _RCLogError)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_WARNING, _RCLogWarn)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_NOTICE, _RCLogNotice)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_INFO, _RCLogInfo)
RC_MAKE_LOG_FUNCTION_DECL(ASL_LEVEL_DEBUG, _RCLogDebug)

#undef RC_MAKE_LOG_FUNCTION_DECL

// Add 'short' flavours as macros, to be able to take advantage of file names line numbers
#define RCLogEmerg(...) \
do { \
if (ENABLE_LOGGING) \
_RCLogEmerg(basename((char *)__FILE__), __LINE__, __VA_ARGS__); \
} while (0)

#define RCLogError(...) \
do { \
if (ENABLE_LOGGING) \
_RCLogError(basename((char *)__FILE__), __LINE__, __VA_ARGS__); \
} while (0)

#define RCLogWarn(...) \
do { \
if (ENABLE_LOGGING) \
_RCLogWarn(basename((char *)__FILE__), __LINE__, __VA_ARGS__); \
} while (0)

#define RCLogNotice(...) \
do { \
if (ENABLE_LOGGING) \
_RCLogNotice(basename((char *)__FILE__), __LINE__, __VA_ARGS__); \
} while (0)

#define RCLogInfo(...) \
do { \
if (ENABLE_LOGGING) \
    _RCLogInfo(basename((char *)__FILE__), __LINE__, __VA_ARGS__); \
} while (0)

#define RCLogDebug(...) \
do { \
if (ENABLE_LOGGING) \
    _RCLogDebug(basename((char *)__FILE__), __LINE__, __VA_ARGS__); \
} while (0)

/*
 ExternC void RCLogDebug(char *format, ...);
 ExternC void RCLogInfo(char *format, ...);
 ExternC void RCLogNotice(char *format, ...);
 ExternC void RCLogWarn(char *format, ...);
 ExternC void RCLogError(char *format, ...);
 ExternC void RCLogCrit(char *format, ...);
 ExternC void RCLogAlert(char *format, ...);
 ExternC void RCLogEmerg(char *format, ...);
 */

#endif
