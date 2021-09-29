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

OVS_ENABLE="$(syscfg get CONFIG_INANGO_INANGOPLUG_ENABLE)"
NCPU_EXEC_SCRIPT_NAME="create_inangoplug_enable.sh"
loopBreakCounter=0

while [ ! -f /tmp/utopia_inited ]
do
    if [ "$loopBreakCounter" -ne 30 ]; then
        echo "[Inangoplug] wait for utopia..."
        loopBreakCounter=$((loopBreakCounter+1))
        sleep 1
    else
        echo "[Inangoplug] utopia is not started, exiting..."
        exit 1
    fi
done

if [ "${OVS_ENABLE}" == "true" ]
then
    ncpu_exec -ep "${NCPU_EXEC_SCRIPT_NAME}"
    if [ $? -eq 0 ]
    then
        echo "Inango Plug is enabled, starting..."
        exit 0
    else
        echo "Failed to start Inango Plug, exiting..."
        exit 1
    fi
fi

echo "Inango Plug is disabled, exiting..."
exit 1
