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

SYSCFG_DB_INITED=/tmp/syscfg_inited
loopBreakCounter=0

while [ ! -f "${SYSCFG_DB_INITED}" ]
do
    if [ "$loopBreakCounter" -ne 30 ]; then
        echo "[ovs-infra] wait for syscfg..."
        loopBreakCounter=$((loopBreakCounter+1))
        sleep 1
    else
        echo "[ovs-infra] syscfg is not initialized, exiting..."
        exit 1
    fi
done

OVS_INFRASTRUCTURE_ENABLE="$(syscfg get CONFIG_OVS_INFRASTRUCTURE_ENABLE)"

if [ "${OVS_INFRASTRUCTURE_ENABLE}" == "true" ]
then
    echo "OVS Infrastructure is enabled, starting..."
    exit 0
else
    echo "Failed to start OVS Infrastructure, exiting..."
    exit 1
fi

echo "OVS Infrastructure is disabled, exiting..."
exit 1
