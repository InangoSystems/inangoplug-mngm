#include "rdk_debug.h"

/**
 * @brief Configures different log level CcspInangoplugComponent
 */
#define inangoplug_log_error(...)       inangoplug_log(RDK_LOG_ERROR, __VA_ARGS__)
#define inangoplug_log_info(...)        inangoplug_log(RDK_LOG_INFO, __VA_ARGS__)
#define inangoplug_log_warning(...)     inangoplug_log(RDK_LOG_WARN, __VA_ARGS__)
#define inangoplug_log_debug(...)       inangoplug_log(RDK_LOG_DEBUG, __VA_ARGS__)

void inangoplug_log(unsigned int level, const char *msg, ...)
    __attribute__((format (printf, 2, 3)));

void inangoplug_log_init();
