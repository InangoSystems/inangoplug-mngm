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
INANGOPLUG_OVS_PROTO="tcp"

# Connection properties :
BR_NAME=brlan0
INANGOPLUG_MAC_SRC_IF_NAME=erouter0
INANGOPLUG_DATAPATH_PREFIX=0000
CLIENT_ID_PATH="/etc/inangoplug/clientid"

# Registration data below
INANGOPLUG_SC_PRIVKEY=/sc-privkey.pem
INANGOPLUG_SC_CERT=/sc-cert.pem
INANGOPLUG_CA_CERT=/cacert.pem
INANGOPLUG_DPID=

# Registration host and port here
INANGOPLUG_SO_SERV="$(dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugSOServer \
        | grep -E -o "value:.*$" \
        | sed -e 's/value://' \
        | sed -e 's/[[:space:]]*//g' \
        | sed -e 's/:[[:digit:]]*$//g' \
    )"
INANGOPLUG_HTTPS_PORT="$(dmcli eRT getv Device.X_INANGO_Inangoplug.InangoplugSOServer \
        | grep -E -o "value:.*$" \
        | sed -e 's/value://' \
        | sed -e 's/[[:space:]]*//g' \
        | grep -E -o ":[[:digit:]]*$" \
        | sed -e 's/://' \
     )"
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

    # Exit if we didn't get "address" or "port" array in $INANGOPLUG_RESPONSE
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
    if [ -f "${CLIENT_ID_PATH}" ]; then
        CLIENT_ID="$(sha1sum "${CLIENT_ID_PATH}" | cut -d " " -f 1)"
    fi
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} other_config:dp-desc="${CLIENT_ID}"
}

configure_bridge ()
{
    # Configure brlan0 to use OpenFlow13 due server can work only with this version
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} protocols=OpenFlow13
    set_client_id
    ${INANGOPLUG_OVS_CTL} set bridge ${BR_NAME} other-config:disable-in-band=true

    ${INANGOPLUG_OVS_CTL} set-controller ${BR_NAME} ${CONTROLLERS} || \
        { echo "Failed to set OvS bridge controller..." && return 1; }
    ${INANGOPLUG_OVS_CTL} set-manager ${MANAGERS} || \
        { echo "Failed to set OvS bridge manager..." && return 1; }

    echo "Successfully set up OvS bridge..!"
    return 0
}

reg_agent ()
{
    local response=
    local cacet="--insecure"
    local scprivkey="--key ${INANGOPLUG_SC_PRIVKEY}"
    local sccert="--cert ${INANGOPLUG_SC_CERT}"
    local https_port=":${INANGOPLUG_HTTPS_PORT}"
    local loopBreakCounter=0
    local retries=30

    if [ -z "${INANGOPLUG_HTTPS_PORT}" ]; then
        https_port=""
    fi

    if [ "${INANGOPLUG_OVS_PROTO}" = "tcp" ]; then
        scprivkey=""
        sccert=""
    elif [ -s "${INANGOPLUG_CA_CERT}" ]; then
        cacet="--cacert ${INANGOPLUG_CA_CERT}"
    fi

    while [ true ]
    do
        if response="$(curl ${cacet} ${scprivkey} ${sccert} -X GET \
        https://${INANGOPLUG_SO_SERV}${https_port}/agents/controllers?datapathId="${INANGOPLUG_DPID}")"; then
            echo "${response}"
            break
        elif [ "$loopBreakCounter" -ne "$retries" ]; then
            echo "Connection to Inango SO server failed, repeating request..."
            loopBreakCounter=$((loopBreakCounter+1))
            sleep 1
        else
            echo "Can't establish connection to Inango SO server, exiting..."
            exit 1
        fi
    done
}

inangoplug_register()
{
    local inangoplug_register_response=

    if [ -z "${INANGOPLUG_DPID}" ] || [ -z "${INANGOPLUG_SO_SERV}" ]; then
        return 1
    fi

    echo "-------- register board in INANGOPLUG setup --------"

    inangoplug_register_response="$(reg_agent)"|| { echo "Can't register Inango Plug, exiting..." && exit 1; }
    echo "$inangoplug_register_response"
    return 0
}

# Generic function
# Creating mac_id
# Return: mac_id
get_dpid () {
    if [ ! -z "${INANGOPLUG_DPID}" ]; then
        return
    fi
    local mac="$(cat /sys/class/net/${INANGOPLUG_MAC_SRC_IF_NAME}/address )"
    echo "${INANGOPLUG_DATAPATH_PREFIX}${mac//:/}"
}

set_ssl_certificates()
{
    ${INANGOPLUG_OVS_CTL} set-ssl "${INANGOPLUG_SC_PRIVKEY}" "${INANGOPLUG_SC_CERT}" "${INANGOPLUG_CA_CERT}"
}

init_certificates_var() {
    if [ -s "${CONFIG_INANGO_INANGOPLUG_SSL_RUNTIME_DIR}${INANGOPLUG_SC_PRIVKEY}" ]; then
        INANGOPLUG_SC_PRIVKEY="${CONFIG_INANGO_INANGOPLUG_SSL_RUNTIME_DIR}${INANGOPLUG_SC_PRIVKEY}"
    elif [ -s "${CONFIG_INANGO_INANGOPLUG_SSL_DEFAULT_DIR}${INANGOPLUG_SC_PRIVKEY}" ]; then
        INANGOPLUG_SC_PRIVKEY="${CONFIG_INANGO_INANGOPLUG_SSL_DEFAULT_DIR}${INANGOPLUG_SC_PRIVKEY}"
    else
        echo "File sc-privkey.pem is absent or null, choose tcp..."
        return 1
    fi

    if [ -s "${CONFIG_INANGO_INANGOPLUG_SSL_RUNTIME_DIR}${INANGOPLUG_SC_CERT}" ]; then
        INANGOPLUG_SC_CERT="${CONFIG_INANGO_INANGOPLUG_SSL_RUNTIME_DIR}${INANGOPLUG_SC_CERT}"
    elif [ -s "${CONFIG_INANGO_INANGOPLUG_SSL_DEFAULT_DIR}${INANGOPLUG_SC_CERT}" ]; then
        INANGOPLUG_SC_CERT="${CONFIG_INANGO_INANGOPLUG_SSL_DEFAULT_DIR}${INANGOPLUG_SC_CERT}"
    else
        echo "File sc-cert.pem is absent or null, choose tcp..."
        return 1
    fi

    if [ -s "${CONFIG_INANGO_INANGOPLUG_SSL_RUNTIME_DIR}${INANGOPLUG_CA_CERT}" ]; then
        INANGOPLUG_CA_CERT="${CONFIG_INANGO_INANGOPLUG_SSL_RUNTIME_DIR}${INANGOPLUG_CA_CERT}"
    elif [ -s "${CONFIG_INANGO_INANGOPLUG_SSL_DEFAULT_DIR}${INANGOPLUG_CA_CERT}" ]; then
        INANGOPLUG_CA_CERT="${CONFIG_INANGO_INANGOPLUG_SSL_DEFAULT_DIR}${INANGOPLUG_CA_CERT}"
    else
        INANGOPLUG_CA_CERT="none"
    fi

    INANGOPLUG_OVS_PROTO="ssl"
    return 0
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
    if [ -z "${INANGOPLUG_SO_SERV}" ]
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

prepare_bridge() {
    # Remove old controller and manager addresses
    ${INANGOPLUG_OVS_CTL} del-controller ${BR_NAME}
    ${INANGOPLUG_OVS_CTL} del-manager
}
###
##  ~ Main chunk
###

wait_for_wan_address

INANGOPLUG_DPID="$(get_dpid)"

wait_for_bridge

set_datapath_id

check_inango_so_serv_addr || { echo "Inango SO server is not set" && exit 1; }

prepare_bridge

init_certificates_var && set_ssl_certificates

wait_for_internet

INANGOPLUG_RESPONSE="$(inangoplug_register)" || { echo "Registration on Inango SO platform failed" && exit 1; }

# Getting openflow host and port from INANGOPLUG json response
resolve_controllers || { echo "Failed to get OpenFlow Controller or Manager..." && exit 1; }

configure_bridge
