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

source /etc/inangoplug/inangoplug.cfg

INANGOPLUG_OVS_CTL=ovs-vsctl
INANGOPLUG_OF_CTL=ovs-ofctl
INANGOPLUG_OVS_PROTO=

# Connection properties :
BR_NAME=brlan0
INANGOPLUG_MAC_SRC_IF_NAME=erouter0
INANGOPLUG_DATAPATH_PREFIX=0000
CLIENT_ID_PATH="/etc/inangoplug/clientid"

# Openflow host and port here
OF_IP=
OF_PORT=6653
# Registration data below
INANGOPLUG_SC_PRIVKEY="${CONFIG_INANGO_INANGOPLUG_SSL_DIR}/sc-privkey.pem"
INANGOPLUG_SC_CERT="${CONFIG_INANGO_INANGOPLUG_SSL_DIR}/sc-cert.pem"
INANGOPLUG_CA_CERT="${CONFIG_INANGO_INANGOPLUG_SSL_DIR}/cacert.pem"
INANGOPLUG_DPID=
# Registration host and port here
INANGOPLUG_SO_SERV=`dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugSOServer | grep value | cut -d ':' -f 3 | sed -e 's/^[[:space:]]*//' | sed 's/ *$//g'`
INANGOPLUG_OF_PORT=`dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugSOServer | grep value | cut -d ':' -f 4 | sed -e 's/^[[:space:]]*//' | sed 's/ *$//g'`
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

    # Exit if we didn't get "controllers" array in $INANGOPLUG_RESPONSE
    if [ -z "${addresses}" ] || [ -z "${ports}" ] ; then
        return 1
    fi

    # Prepare $CONTROLLERS and $MANAGERS arrays
    for addr in ${addresses}; do
        local cur_port="$(get_first_in_list ${ports})"
        ports="$(shift_list ${ports})"
        CONTROLLERS="${CONTROLLERS}${INANGOPLUG_OVS_PROTO}:${addr}:${cur_port} "
        MANAGERS="${MANAGERS}${INANGOPLUG_OVS_PROTO}:${addr} "
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

set_client_id () {
    local CLIENT_ID="UNKNOWN"
    if [ -f ${CLIENT_ID_PATH} ]; then
        CLIENT_ID=`sha1sum "${CLIENT_ID_PATH}" | cut -d " " -f 1`
    fi
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} other_config:dp-desc="${CLIENT_ID}"
}

configure_bridge ()
{
    # Configure brlan0 to use OpenFlow13 due server can work only with this version
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} protocols=OpenFlow13
    set_client_id
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} other-config:disable-in-band=true

    # Remove old controller and manager addresses
    ${INANGOPLUG_OVS_CTL} del-controller ${BR_NAME}
    ${INANGOPLUG_OVS_CTL} del-manager

    resolve_controllers
    if [ "$?" -eq "0" ]; then
        ${INANGOPLUG_OVS_CTL} set-controller ${BR_NAME} ${CONTROLLERS} || { echo "Failed to set OvS bridge controller..." && return 1; }
        ${INANGOPLUG_OVS_CTL} set-manager ${MANAGERS} || { echo "Failed to set OvS bridge manager..." && return 1; }
    else
        local ip_addr=$(get_right_ip_addr_format ${OF_IP})
        ${INANGOPLUG_OVS_CTL} set-controller ${BR_NAME} ${INANGOPLUG_OVS_PROTO}:${ip_addr}:${OF_PORT} || { echo "Failed to set OvS bridge controller..." && return 1; }
        ${INANGOPLUG_OVS_CTL} set-manager ${INANGOPLUG_OVS_PROTO}:${ip_addr} || { echo "Failed to set OvS bridge manager..." && return 1; }
    fi

    echo "Successfully set up OvS bridge..!"
    return 0
}

reg_agent ()
{
    local response=
    local cacet="--insecure"
    local scprivkey="--key ${INANGOPLUG_SC_PRIVKEY}"
    local sccert="--cert ${INANGOPLUG_SC_CERT}"
    if [ ${INANGOPLUG_OVS_PROTO} = "tcp" ]; then
        scprivkey=""
        sccert=""
    elif [ -s ${INANGOPLUG_CA_CERT} ]; then
        cacet="--cacert ${INANGOPLUG_CA_CERT}"   
    fi
    response=$(curl ${cacet} ${scprivkey} ${sccert} \
        -X GET https://"${INANGOPLUG_SO_SERV}":${INANGOPLUG_OF_PORT}/agents/controllers?datapathId=${INANGOPLUG_DPID}) 
    echo "${response}"
}

inangoplug_register()
{
    local inangoplug_register_response=

    if [ -z ${INANGOPLUG_DPID} ] || [ -z ${INANGOPLUG_SO_SERV} ] || [ -z ${INANGOPLUG_OF_PORT} ]; then
        return 1
    fi

    echo "-------- register board in INANGOPLUG setup --------"

    inangoplug_register_response=$(reg_agent)
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

    parsed_port=$(echo "${INANGOPLUG_RESPONSE}" | sed 's/}//g' | sed 's/{//g' | tr ',' '\n' | grep "port" | sed 's/.*://')
    if [ -n "${parsed_port}" ]; then
        OF_PORT="${parsed_port}"
    fi


    parsed_host=$(echo "${INANGOPLUG_RESPONSE}" | sed 's/[{}"]//g' | tr ',' '\n' | grep "address" | sed -e 's/data:\[address://')
    if [ -n "${parsed_host}" ]; then
        OF_IP=${parsed_host}
    fi

    if [ -z ${OF_IP} ] || [ -z ${OF_PORT} ]; then
        return 1
    fi
    return 0
}

set_ssl_certificates() {
    if [ ! -s ${INANGOPLUG_CA_CERT} ]; then
        INANGOPLUG_CA_CERT="none"
    fi
    ${INANGOPLUG_OVS_CTL} set-ssl ${INANGOPLUG_SC_PRIVKEY} ${INANGOPLUG_SC_CERT} ${INANGOPLUG_CA_CERT}
}

set_proto() {
    if [ -s ${INANGOPLUG_SC_PRIVKEY} ] && [ -s ${INANGOPLUG_SC_CERT} ]; then
        echo "ssl"
        set_ssl_certificates
    else
        echo "tcp"
    fi
}

wait_for_internet() {
    while [ true ]
    do
        if  ping -q -c 1 -W 1 ${INANGOPLUG_SO_SERV}  > /dev/null && [ -f /sys/class/net/${INANGOPLUG_MAC_SRC_IF_NAME}/address ]; then
            return 0
        fi
        sleep 10
    done
}

check_inango_so_serv_addr() {
    if [ -z ${INANGOPLUG_SO_SERV} ]
    then
        return 1
    fi
    return 0
}

wait_for_wan_address() {
    echo "Wait for ${INANGOPLUG_MAC_SRC_IF_NAME} mac address..."
    while [ true ]
    do
        if [ "$(sysevent get docsis-initialized)" == "1" ]; then
            return 0
        elif [ "$(sysevent get eth_wan_mac)" != "" ]; then
            return 0
        fi
        sleep 5
    done
}

wait_for_bridge() {
    echo "Wait for ${BR_NAME} bridge..."
    while [ true ]
    do
        if ${INANGOPLUG_OVS_CTL} show | grep -q ${BR_NAME}; then
            return 0
        fi
        sleep 5
    done
}

###
##  ~ Main chunk
###

wait_for_wan_address

INANGOPLUG_DPID=$(get_dpid)

wait_for_bridge

set_datapath_id

check_inango_so_serv_addr || { echo "Inango SO server is not set" && exit 1; }

INANGOPLUG_OVS_PROTO=$(set_proto)

wait_for_internet

INANGOPLUG_RESPONSE=$(inangoplug_register) || { echo "Registration on INANGOPLUG platform failed" && exit 1; }

# Getting openflow host and port from INANGOPLUG json response
set_of_host || { echo "Failed to obtain OF_IP and OF_PORT" && exit 1; }

configure_bridge
