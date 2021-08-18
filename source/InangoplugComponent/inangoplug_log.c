#include <unistd.h>
#include <stdlib.h>
#include "ssp_global.h"
#include "inangoplug_log.h"

#define DEBUG_INI_NAME  "/etc/debug.ini"
#define BUFF_SIZE 4096

/**
 * @brief inangoplug_log_init Initialize RDK Logger
 */
void inangoplug_log_init()
{

    char buffer[5] = {0};
    if (0 == syscfg_get(NULL, "X_INANGO_Inangoplug_LogLevel", buffer, sizeof(buffer)) &&  (buffer[0] != '\0'))
    {
        INANGOPLUG_RDKLogLevel = (ULONG)atoi(buffer);
    }
    memset(buffer, 0, sizeof(buffer));
    if (0 == syscfg_get(NULL, "X_INANGO_Inangoplug_LoggerEnable", buffer, sizeof(buffer)) && ( buffer[0] != '\0'))
    {
        INANGOPLUG_RDKLogEnable = (BOOL)atoi(buffer);
    }

    rdk_logger_init(DEBUG_INI_NAME);
    inangoplug_log_debug("CcspInangoplugComponent RDKLog values: INANGOPLUG_RDKLogLevel:%u, INANGOPLUG_RDKLogEnable:%d\n", INANGOPLUG_RDKLogLevel, INANGOPLUG_RDKLogEnable);
}

void inangoplug_log(unsigned int level, const char *msg, ...)
{
    va_list arg;
    char *pTempChar = NULL;
    int ret = 0;

    if (level <= INANGOPLUG_RDKLogLevel && INANGOPLUG_RDKLogEnable)
    {
        pTempChar = (char *)malloc(BUFF_SIZE);
        if (pTempChar)
        {
            va_start(arg, msg);
            ret = vsnprintf(pTempChar, BUFF_SIZE, msg, arg);
            if (ret < 0)
            {
                perror(pTempChar);
            }
            va_end(arg);
            RDK_LOG(level, "LOG.RDK.INANGOPLUG", pTempChar);
            free(pTempChar);
        }
    }
}

