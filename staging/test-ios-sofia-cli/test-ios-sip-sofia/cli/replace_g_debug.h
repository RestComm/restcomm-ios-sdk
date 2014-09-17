/* Suppress warnings when GCC is in -pedantic mode and not -std=c99
 */
#if (__GNUC__ >= 3 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 96))
#pragma GCC system_header
#endif

G_BEGIN_DECLS

#ifdef G_HAVE_ISO_VARARGS
#define g_debug(...)    g_log (G_LOG_DOMAIN,         \
                               G_LOG_LEVEL_DEBUG,    \
                               __VA_ARGS__)
#elif defined(G_HAVE_GNUC_VARARGS)
#define g_debug(format...)      g_log (G_LOG_DOMAIN,         \
                                       G_LOG_LEVEL_DEBUG,    \
                                       format)
#else   /* no varargs macros */
static void
g_debug (const gchar *format,
         ...)
{
  va_list args;
  va_start (args, format);
  g_logv (G_LOG_DOMAIN, G_LOG_LEVEL_DEBUG, format, args);
  va_end (args);
}
#endif

G_END_DECLS
