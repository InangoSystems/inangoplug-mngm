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

/**************************************************************************

    module: cosa_apis_plugininangoplugobj.h

        For COSA Data Model Library Development

    -------------------------------------------------------------------

    description:

        This file defines the apis for objects to support Data Model Library.

    -------------------------------------------------------------------


    author:

        COSA XML TOOL CODE GENERATOR 1.0

    -------------------------------------------------------------------

    revision:

        12/02/2010    initial revision.

**************************************************************************/


#ifndef  _COSA_APIS_PLUGINSAMPLEOBJ_H
#define  _COSA_APIS_PLUGINSAMPLEOBJ_H

#include "slap_definitions.h"

/***********************************************************************

 APIs for Object:

   Device.InangoplugComponent. 

    *  InangoplugComponent_GetParamStringValue
    *  InangoplugComponent_SetParamStringValue
    *  InangoplugComponent_GetParamBoolValue
    *  InangoplugComponent_SetParamBoolValue

***********************************************************************/
BOOL
InangoplugComponent_GetParamStringValue
	(
		ANSC_HANDLE 				hInsContext,
		char*						pParamName,
		char*						pValue,
		ULONG*						pUlSize
	);

BOOL
InangoplugComponent_SetParamStringValue
    (
        ANSC_HANDLE                 hInsContext,
        char*                       pParamName,
        char*                       pString
    );

BOOL
InangoplugComponent_GetParamBoolValue
	(
        ANSC_HANDLE                 hInsContext,
        char*                       ParamName,
        BOOL*                       pBool
	);

BOOL
InangoplugComponent_SetParamBoolValue
    (
        ANSC_HANDLE                 hInsContext,
        char*                       pParamName,
        BOOL                        bValue
    );

#endif
