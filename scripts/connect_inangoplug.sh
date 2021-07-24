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

INANGOPLUG_OVS_CTL=ovs-vsctl

# Connection properties :
BR_NAME=brlan0
INANGOPLUG_MAC_SRC_IF_NAME=erouter0
INANGOPLUG_DATAPATH_PREFIX=0000

# Openflow host and port here
OF_IP=
OF_PORT=6653
# Registration data below
INANGOPLUG_LOGIN=`dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugLogin | grep value | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//' | sed 's/ *$//g'`
INANGOPLUG_PASSWORD=`dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugPassword | grep value | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//' | sed 's/ *$//g'`
INANGOPLUG_DPID=
# Registration host and port here
INANGOPLUG_SO_SERV=`dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugSOServer | grep value | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//' | sed 's/ *$//g'`
INANGOPLUG_OF_PORT=8090
INANGOPLUG_RESPONSE=

shift_list()
{
    shift
    echo $*
}

get_first_in_list()
{
    echo $1
}

# Setting CONTROLLERS and MANAGERS
# Return: 0 success, 1 otherwise
resolve_controllers ()
{
    local addresses=
    local ports=

    # Get addresses and ports from response
    addresses="$(echo "${INANGOPLUG_RESPONSE}" | tr '{},' '\n' | grep 'address' | sed 's/"address"://' | sed 's/[" ]//g')"
    ports="$(echo "${INANGOPLUG_RESPONSE}" | tr '{},' '\n' | grep 'port' | sed 's/"port"://' | sed 's/[" ]//g')"

    # Remove old controller and manager addresses
    ovs-vsctl del-controller ${BR_NAME}
    ovs-vsctl del-manager

    # Exit if we didn't get "controllers" array in $INANGOPLUG_RESPONSE
    if [ -z "${addresses}" ] || [ -z "${ports}" ] ; then
        return 1
    fi

    # Prepare $CONTROLLERS and $MANAGERS arrays
    for addr in ${addresses}; do
        local cur_port="$(get_first_in_list ${ports})"
        ports="$(shift_list ${ports})"
        CONTROLLERS="${CONTROLLERS}tcp:${addr}:${cur_port} "
        MANAGERS="${MANAGERS}tcp:${addr} "
    done

    # Return error code if we didn't get any addresses
    if [ -z "${CONTROLLERS}" ] || [ -z "${MANAGERS}" ] ; then
        return 1
    fi
    return 0
}

# Setting datapath-id for ovs-bridge
set_datapath_id () {
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} other-config:datapath-id=${INANGOPLUG_DPID}
}

configure_bridge ()
{
    set_datapath_id
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} other-config:disable-in-band=true

    # Remove old controller and manager addresses
    ovs-vsctl del-controller ${BR_NAME}
    ovs-vsctl del-manager

    resolve_controllers
    if [ "$?" -eq "0" ]; then
        ${INANGOPLUG_OVS_CTL} set-controller ${BR_NAME} ${CONTROLLERS} || { echo "Failed to set OvS bridge controller..." && return 1; }
        ${INANGOPLUG_OVS_CTL} set-manager ${MANAGERS} || { echo "Failed to set OvS bridge manager..." && return 1; }
    else
        local ip_addr=$(get_right_ip_addr_format ${OF_IP})
        ${INANGOPLUG_OVS_CTL} set-controller ${BR_NAME} tcp:${ip_addr}:${OF_PORT} || { echo "Failed to set OvS bridge controller..." && return 1; }
        ${INANGOPLUG_OVS_CTL} set-manager tcp:${ip_addr} || { echo "Failed to set OvS bridge manager..." && return 1; }
    fi
    echo "Successfully set up OvS bridge..!"
    return 0
}

# Setting OF_IP and OF_PORT
# Return: 0 success, 1 otherwise
set_of_host () {
    local parsed_host=
    local parsed_port=

    parsed_host=$(echo "${INANGOPLUG_RESPONSE}" | sed 's/[{}"]//g' | tr ',' '\n' | grep "ofHost" | sed 's/ofHost://')
    if [ -n "${parsed_host}" ]; then
        OF_IP=${parsed_host}
    fi

    parsed_port=$(echo "${INANGOPLUG_RESPONSE}" | sed 's/}//g' | sed 's/{//g' | tr ',' '\n' | grep "ofPort" | sed 's/.*://')
    if [ -n "${parsed_port}" ]; then
        OF_PORT="${parsed_port}"
    fi

    if [ -z ${OF_IP} ] || [ -z ${OF_PORT} ]; then
        return 1
    fi
    return 0
}

get_token ()
{
    local token=
    token=$(curl -H 'Content-Type: application/json' \
        -X PUT -d "{\"login\": \"${INANGOPLUG_LOGIN}\", \"password\": \"${INANGOPLUG_PASSWORD}\"}" http://"${INANGOPLUG_SO_SERV}":${INANGOPLUG_OF_PORT}/auth)
    token=$(echo ${token} | grep "data" | tr -d "{},\"" | cut -d ':' -f 4)
    echo "${token}"
}

reg_agent ()
{
    local token=$1
    local response=

    response=$(curl -H "Content-Type: application/json" \
        -H "authorization: $token" -X POST -d "{\"datapathId\": \"${INANGOPLUG_DPID}\"}" http://"${INANGOPLUG_SO_SERV}":${INANGOPLUG_OF_PORT}/agents)
    echo "${response}"
}

inangoplug_register()
{
    # Configure brlan0 to use OpenFlow13 due server can work only with this version
    ovs-vsctl set bridge ${BR_NAME} protocols=OpenFlow13

    local inangoplug_register_token=
    local inangoplug_register_response=

    if [ -z ${INANGOPLUG_LOGIN} ] || [ -z ${INANGOPLUG_PASSWORD} ] || [ -z ${INANGOPLUG_DPID} ] || [ -z ${INANGOPLUG_SO_SERV} ] || [ -z ${INANGOPLUG_OF_PORT} ]; then
        return 1
    fi

    echo "-------- register board in INANGOPLUG setup --------"

    inangoplug_register_token=$(get_token)
    inangoplug_register_response=$(reg_agent ${inangoplug_register_token})
    echo "$inangoplug_register_response"
    return 0
}

# Generic function
# Creating mac_id
# Return: mac_id
get_dpid () {
    if [ ! -z ${INANGOPLUG_DPID} ]; then
        return
    fi
    local mac=$(cat /sys/class/net/${INANGOPLUG_MAC_SRC_IF_NAME}/address )
    echo "${INANGOPLUG_DATAPATH_PREFIX}${mac//:/}"
}

# Setting OF_IP and OF_PORT
# Return: 0 success, 1 otherwise
set_of_host () {
    local parsed_host=
    local parsed_port=

    parsed_host=$(echo "${INANGOPLUG_RESPONSE}" | sed 's/[{}"]//g' | tr ',' '\n' | grep "ofHost" | sed 's/ofHost://')
    if [ -n "${parsed_host}" ]; then
        OF_IP=${parsed_host}
    fi

    parsed_port=$(echo "${INANGOPLUG_RESPONSE}" | sed 's/}//g' | sed 's/{//g' | tr ',' '\n' | grep "ofPort" | sed 's/.*://')
    if [ -n "${parsed_port}" ]; then
        OF_PORT="${parsed_port}"
    fi

    if [ -z ${OF_IP} ] || [ -z ${OF_PORT} ]; then
        return 1
    fi
    return 0
}

check_internet() {
    if  ping -q -c 1 -W 1 ${INANGOPLUG_SO_SERV}  > /dev/null && [ -f /sys/class/net/${INANGOPLUG_MAC_SRC_IF_NAME}/address ]; then
        return 0
    else
        ovs-ofctl add-flow ${BR_NAME} action=normal
        return 1
    fi
}

###
##  ~ Main chunk
###

check_internet || { echo "Board doesn't have internet connection" && exit 1; }

INANGOPLUG_DPID=$(get_dpid)

INANGOPLUG_RESPONSE=$(inangoplug_register) || { echo "Registration on INANGOPLUG platform failed" && exit 1; }

# Getting openflow host and port from INANGOPLUG json response
set_of_host || { echo "Failed to obtain OF_IP and OF_PORT" && exit 1; }

configure_bridge
