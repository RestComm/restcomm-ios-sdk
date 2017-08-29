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

#include "common.h"
#include <asl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdbool.h>
#include <string.h>
#import <UIKit/UIKit.h>

//#include "TestFairy.h"

// TODO: asl man page says that the best practice is to use separate client handle from each
// thread for which you want logging. Currently we don't do that and I haven't seen any issues
// Let's keep that in mind and revisit at some point in the future
static bool loggingInitialized = false;
static aslmsg msg = NULL;

// This is actually used as a callback and sofia default logger calls it to do its logging instead of the default (i.e. that ends up calling printf)
// Notice that right now this is called only for transport layer SIP messages (i.e. full SIP messages), rest of the logging comes from actively calling
// any of the RCLog* macros from our code
// TODO: At some point it might be worth hooking other sofia logging facilities as well, like nua, nta, tport, etc so that we can retrieve logs from those
// and have them use our mechanism that properly logs them on: xcode console, device console and Test Fairy (i.e. remote logging)
void customSofiaLoggerCallback(void *stream, char const *fmt, va_list ap)
{
    char message[LOG_BUFFER_SIZE];
    vsnprintf(message, sizeof(message), fmt, ap);
    if (strcmp(message, "") && strcmp(message, "\n")) {
        RCLogDebug(message);
    
        //NSString * format = [[NSString stringWithUTF8String:fmt] stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
        //TFLogv(format, ap);
    }
}

void initializeLogging(void)
{
    if (!loggingInitialized) {
        // device console
        asl_set_filter(NULL, ASL_FILTER_MASK_UPTO(ASL_LEVEL_NOTICE));

        if (SYSTEM_VERSION_LESS_THAN(@"10.0")) {
            // For earlier versions that iOS 10.0, we need additional handling so that logs show up in xcode console (otherwise they only show in device console.
            // Moreover, leaving those in iOS 10.0 and above duplicates messages and creates a mess
            // add STDERR (i.e. xcode console) to ASL facilities
            asl_add_log_file(NULL, STDERR_FILENO);
            // xcode console
            asl_set_output_file_filter(NULL, STDERR_FILENO, ASL_FILTER_MASK_UPTO(ASL_LEVEL_NOTICE));
        }
        
        // initialize and configure the message structure
        msg = asl_new(ASL_TYPE_MSG);
        // Important: without this asl messages never go to device log (only to xcode console)
        asl_set(msg, ASL_KEY_READ_UID, "-1");
        
        loggingInitialized = true;
    }
}

void finalizeLogging(void)
{
    asl_free(msg);
}

void setLogLevel(int level)
{
    // device console
    asl_set_filter(NULL, ASL_FILTER_MASK_UPTO(level));

    if (SYSTEM_VERSION_LESS_THAN(@"10.0")) {
        // xcode console
        asl_set_output_file_filter(NULL, STDERR_FILENO, ASL_FILTER_MASK_UPTO(level));
    }
}

#define ASL_LEVEL_EMERG   0
#define ASL_LEVEL_ALERT   1
#define ASL_LEVEL_CRIT    2
#define ASL_LEVEL_ERR     3
#define ASL_LEVEL_WARNING 4
#define ASL_LEVEL_NOTICE  5
#define ASL_LEVEL_INFO    6
#define ASL_LEVEL_DEBUG   7

char * levelNumber2String(int level)
{
    // 0
    if (level == ASL_LEVEL_EMERG) {
        return "EMERGENCY";
    }
    // 1
    if (level == ASL_LEVEL_ALERT) {
        return "ALERT";
    }
    // 2
    if (level == ASL_LEVEL_CRIT) {
        return "CRITICAL";
    }
    // 3
    if (level == ASL_LEVEL_ERR) {
        return "ERROR";
    }
    // 4
    if (level == ASL_LEVEL_WARNING) {
        return "WARN";
    }
    // 5
    if (level == ASL_LEVEL_NOTICE) {
        return "NOTICE";
    }
    // 6
    if (level == ASL_LEVEL_INFO) {
        return "INFO";
    }
    // 7
    if (level == ASL_LEVEL_DEBUG) {
        return "DEBUG";
    }
    
    return "DEBUG";
}

#define RC_MAKE_LOG_FUNCTION(LEVEL, NAME) \
void NAME (const char * filename, const int linenumber, const char *format, ...) \
{ \
va_list args; \
va_start(args, format); \
char message[LOG_BUFFER_SIZE]; \
vsnprintf(message, sizeof(message), format, args); \
asl_log(NULL, msg, (LEVEL), "(%s:%d) %s", filename, linenumber, message); \
va_end(args); \
}

// Generate a function definition for each level. Keep in mind that these are the 'extended' flavours, that also take filename and line number
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_EMERG, _RCLogEmerg)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_ALERT, _RCLogAlert)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_CRIT, _RCLogCrit)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_ERR, _RCLogError)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_WARNING, _RCLogWarn)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_NOTICE, _RCLogNotice)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_INFO, _RCLogInfo)
RC_MAKE_LOG_FUNCTION(ASL_LEVEL_DEBUG, _RCLogDebug)

#undef RC_MAKE_LOG_FUNCTION

/*
void RCLogDebug(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_DEBUG), "%s", string);
    va_end(args);
}

void RCLogInfo(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_INFO), "%s", string);
    va_end(args);
}

void RCLogNotice(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_NOTICE), "%s", string);
    va_end(args);
}

void RCLogWarn(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_WARNING), "%s", string);
    va_end(args);
}

void RCLogError(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_ERR), "%s", string);
    va_end(args);
}

void RCLogCrit(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_CRIT), "%s", string);
    va_end(args);
}

void RCLogAlert(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_ALERT), "%s", string);
    va_end(args);
}

void RCLogEmerg(char *format, ...)
{
    va_list args;
    va_start(args, format);
    char string[LOG_BUFFER_SIZE];
    snprintf(string, sizeof(string), format, args);
    asl_log(NULL, NULL, (ASL_LEVEL_EMERG), "%s", string);
    va_end(args);
}
 */
