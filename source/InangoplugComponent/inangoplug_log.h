#include "rdk_debug.h"

#define DEBUG_INI_NAME  "/etc/debug.ini"

#define inangoplug_log_init()    rdk_logger_init(DEBUG_INI_NAME)

/**
 * @brief Configures different log level CcspInangoplugComponent
 */
#define inangoplug_log_error(format, ...)       RDK_LOG(RDK_LOG_ERROR, "LOG.RDK.INANGOPLUG", format, ##__VA_ARGS__)
#define inangoplug_log_info(format, ...)        RDK_LOG(RDK_LOG_INFO, "LOG.RDK.INANGOPLUG", format, ##__VA_ARGS__)
#define inangoplug_log_warning(format, ...)     RDK_LOG(RDK_LOG_WARN, "LOG.RDK.INANGOPLUG", format, ##__VA_ARGS__)
#define inangoplug_log_debug(format, ...)       RDK_LOG(RDK_LOG_DEBUG, "LOG.RDK.INANGOPLUG", format, ##__VA_ARGS__)
