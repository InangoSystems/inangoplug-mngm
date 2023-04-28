#!/bin/sh
################################################################################
#
#  Copyright 2021 Inango Systems Ltd.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
################################################################################

SYSCFG_FILE=@SYSCFG_FILE@
FACTORY_RESET_KEY=factory_reset
FACTORY_RESET_RGWIFI=y
INANGOPLUG_KEY=CONFIG_OVS_INFRASTRUCTURE_ENABLE
INANGOPLUG_DEFAULT_FILE=/etc/inangoplug/inangoplug_defaults
NCPU_EXEC_SCRIPT_NAME="create_inangoplug_enable.sh"

echo "Check OVS Infrastructure is enabled"
if [ ! -f "${SYSCFG_FILE}" ]
then
    echo "${SYSCFG_FILE} doesn't exists, assume OVS Infrastructure is disabled"
    exit 1
fi

SYSCFG_FR_VAL=$(grep ${FACTORY_RESET_KEY} ${SYSCFG_FILE} | cut -d"=" -f2)

if [ "${SYSCFG_FR_VAL}" = "${FACTORY_RESET_RGWIFI}" ]
then
        echo "Factory reset flag is set, check default configuration ${INANGOPLUG_DEFAULT_FILE}"
        OVS_INFRASTRUCTURE_ENABLE=$(grep ${INANGOPLUG_KEY} ${INANGOPLUG_DEFAULT_FILE} | cut -d"=" -f2)
else
        echo "Check ${SYSCFG_FILE}"
        OVS_INFRASTRUCTURE_ENABLE=$(grep ${INANGOPLUG_KEY} ${SYSCFG_FILE} | cut -d"=" -f2)
fi

if [ "${OVS_INFRASTRUCTURE_ENABLE}" = "true" ]
then
	ncpu_exec -ep "${NCPU_EXEC_SCRIPT_NAME}"
	if [ $? -eq 0 ]
	then
		echo "OVS Infrastructure is enabled, starting..."
		exit 0
	else
		echo "Failed to start OVS Infrastructure, exiting..."
		exit 1
	fi
fi

echo "OVS Infrastructure is disabled"
exit 1
