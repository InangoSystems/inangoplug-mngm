/*
 * If not stated otherwise in this file or this component's Licenses.txt file the
 * following copyright and licenses apply:
 *
 * Copyright 2017 RDK Management
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

/*
 * Includes Inango Systems Ltd's changes/modifications dated: 2021.
 * Changed/modified portions - Copyright (c) 2021, Inango Systems Ltd.
*/

#include "ansc_platform.h"
#include "cosa_apis_inangoplugcomponentplugin.h"
#include "ccsp_syslog.h"
#include "safec_lib_common.h"
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <syscfg/syscfg.h>
#include <errno.h>
#include <stdio.h>
#include "inangoplug_log.h"

#define BUFF_SIZE 4096

extern ANSC_HANDLE bus_handle;//lnt
extern char g_Subsystem[32];//lnt

extern char sc_privkey[64];
extern char sc_cert[64];
extern char ca_cert[64];

/**********************************************************************  

    caller:     owner of this object 

    prototype: 

        BOOL
        InangoplugComponent_GetParamStringValue
            (
                ANSC_HANDLE                 hInsContext,
                char*                       pParamName,
                char*                       pValue,
                ULONG*                      pUlSize
            );

    description:

        This function is called to retrieve string parameter value; 

    argument:   ANSC_HANDLE                 hInsContext,
                The instance handle;

                char*                       pParamName,
                The parameter name;

                char*                       pValue,
                The string value buffer;

                ULONG*                      pUlSize
                The buffer of length of string value;
                Usually size of 1023 will be used.
                If it's not big enough, put required size here and return 1;

    return:     0 if succeeded;
                1 if short of buffer size; (*pUlSize = required size)
                -1 if not supported.

**********************************************************************/
BOOL
InangoplugComponent_GetParamStringValue
    (
        ANSC_HANDLE                 hInsContext,
        char*                       pParamName,
        char*                       pValue,
        ULONG*                      pUlSize
    )
{
    char out_buf[32] = {0};
    errno_t rc = -1;

    if(AnscEqualString(pParamName, "InangoplugDatapathID", TRUE))
    {
        get_datapath_id(pValue, pUlSize);
    }

    if(AnscEqualString(pParamName, "InangoplugSOServer", TRUE))
    {
        if (syscfg_get(NULL, "CONFIG_INANGO_INANGOPLUG_SO_SERVER", out_buf, sizeof(out_buf)) == 0)
        {
            rc = strcpy_s(pValue, *pUlSize, out_buf);
            if (rc != EOK)
            {
                ERR_CHK(rc);
                return FALSE;
            }
        } else {
            return FALSE;
        }
    }

    if(AnscEqualString(pParamName, "InangoplugPrivateKey", TRUE))
    {
        if (*pUlSize > BUFF_SIZE)
        {
            read_file(sc_privkey, pValue, pUlSize);
        } else {
            inangoplug_log_info("InangoplugPrivateKey get incorrect buffer size: required buffer size: %d current size of buffer :%d\n", BUFF_SIZE, *pUlSize);
            *pUlSize = BUFF_SIZE + 1;
            return 1;
        }
    }

    if(AnscEqualString(pParamName, "InangoplugCertificate", TRUE))
    {   
        if (*pUlSize > BUFF_SIZE)
        {
            read_file(sc_cert, pValue, pUlSize);
        } else {
            inangoplug_log_info("InangoplugCertificate get incorrect buffer size: required buffer size: %d current size of buffer :%d\n", BUFF_SIZE, *pUlSize);
            *pUlSize = BUFF_SIZE + 1;
            return 1;
        }
    }

    if(AnscEqualString(pParamName, "InangoplugCACertificate", TRUE))
    {
        if (*pUlSize > BUFF_SIZE)
        {
            read_file(ca_cert, pValue, pUlSize);
        } else {
            inangoplug_log_info("InangoplugCACertificate get incorrect buffer size: required buffer size: %d current size of buffer :%d\n", BUFF_SIZE, *pUlSize);
            *pUlSize = BUFF_SIZE + 1;
            return 1;
        }
    }

    return FALSE;
}

/**********************************************************************  

    caller:     owner of this object 

    prototype: 

       BOOL
       InangoplugComponent_SetParamStringValue
            (
                ANSC_HANDLE                 hInsContext,
                char*                       pParamArray,
                char*                       pString,
            );

    description:

        This function is called to set bulk parameter values; 

    argument:   ANSC_HANDLE                 hInsContext,
                The instance handle;

                char*                       pParamName,
                The parameter name array;

                char*                       pString,
                The size of the array;

    return:     TRUE if succeeded.

**********************************************************************/
BOOL
InangoplugComponent_SetParamStringValue
    (
        ANSC_HANDLE                 hInsContext,
        char*                       pParamName,
        char*                       pString
    )
{

    if(AnscEqualString(pParamName, "InangoplugSOServer", TRUE))
    {
        if (syscfg_set(NULL, "CONFIG_INANGO_INANGOPLUG_SO_SERVER", pString) == 0)
        {
            if (syscfg_commit() == 0){
                system("systemctl restart connect_inangoplug.service");
                return TRUE;
            }
        }
    }

    if(AnscEqualString(pParamName, "InangoplugPrivateKey", TRUE))
    {
        replace_spaces(pString);
        write_to_file(sc_privkey, pString);
        system("systemctl restart connect_inangoplug.service");
        return TRUE;
    }

    if(AnscEqualString(pParamName, "InangoplugCertificate", TRUE))
    {
        replace_spaces(pString);
        write_to_file(sc_cert, pString);
        system("systemctl restart connect_inangoplug.service");
        return TRUE;
    }

    if(AnscEqualString(pParamName, "InangoplugCACertificate", TRUE))
    {
        replace_spaces(pString);
        write_to_file(ca_cert, pString);
        system("systemctl restart connect_inangoplug.service");
        return TRUE;
    }

    return FALSE;
}

/**********************************************************************  

    caller:     owner of this object 

    prototype: 

        BOOL
        InangoplugComponent_GetParamBoolValue
            (
                ANSC_HANDLE                 hInsContext,
                char*                       pParamName,
                BOOL*                       pBool
            );

    description:

        This function is called to retrieve Boolean parameter value;

    argument:   ANSC_HANDLE                 hInsContext,
                The instance handle;

                char*                       pParamName,
                The parameter name;

                BOOL*                       pBool
                The buffer of returned boolean value;

    return:     TRUE if succeeded.

**********************************************************************/
BOOL
InangoplugComponent_GetParamBoolValue
    (
        ANSC_HANDLE                 hInsContext,
        char*                       pParamName,
        BOOL*                       pBool
    )
{
    char out_buf[32] = {0};
    errno_t rc = -1;
    int ind = -1;

    if(AnscEqualString(pParamName, "InangoplugEnable", TRUE))
    {
        if (syscfg_get(NULL, "CONFIG_INANGO_INANGOPLUG_ENABLE", out_buf, sizeof(out_buf)) == 0)
        {
            rc = strcmp_s("true", strlen("true"), out_buf, &ind);
            ERR_CHK(rc);
            if ((rc == EOK) && (ind == 0))
            {
                *pBool = TRUE;
                return TRUE;
            } else {
                *pBool = FALSE;
                return TRUE;
            }
        } else {
            *pBool = FALSE;
            return TRUE;
        }
    }
    return FALSE;
}

/**********************************************************************

    caller:     owner of this object

    prototype:

        BOOL
        InangoplugComponent_SetParamBoolValue
            (
                ANSC_HANDLE                 hInsContext,
                char*                       pParamName,
                BOOL                        bValue
            );

    description:

        This function is called to set Boolean parameter value;

    argument:   ANSC_HANDLE                 hInsContext,
                The instance handle;

                char*                       pParamName,
                The parameter name;

                BOOL                        bValue
                The updated BOOL value;

    return:     TRUE if succeeded.

**********************************************************************/
BOOL
InangoplugComponent_SetParamBoolValue
    (
        ANSC_HANDLE                 hInsContext,
        char*                       pParamName,
        BOOL                        bValue
    )
{
    if(AnscEqualString(pParamName, "InangoplugEnable", TRUE))
    {
        if (syscfg_set(NULL, "CONFIG_INANGO_INANGOPLUG_ENABLE", bValue ? "true" : "false") == 0)
        {
            if (syscfg_commit() == 0){
                return TRUE;
            }
        }
    }
    return FALSE;
}

