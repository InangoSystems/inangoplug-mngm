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

# Script error codes
EXIT_RESTART=1
EXIT_NO_RESTART=2

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
INANGOPLUG_SO_SERV="$(dmcli eRT getv Device.X_INANGO.SOServer \
        | grep -E -o "value:.*$" \
        | sed -e 's/value://' \
        | sed -e 's/[[:space:]]*//g' \
        | sed -e 's/:[[:digit:]]*$//g' \
    )"
INANGOPLUG_HTTPS_PORT="$(dmcli eRT getv Device.X_INANGO.SOServer \
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

    if [ -z "${INANGOPLUG_HTTPS_PORT}" ]; then
        https_port=""
    fi

    if [ "${INANGOPLUG_OVS_PROTO}" = "tcp" ]; then
        scprivkey=""
        sccert=""
    elif [ -s "${INANGOPLUG_CA_CERT}" ]; then
        cacet="--cacert ${INANGOPLUG_CA_CERT}"
    fi


    if response="$(curl ${cacet} ${scprivkey} ${sccert} -X GET \
    https://${INANGOPLUG_SO_SERV}${https_port}/agents/controllers?datapathId="${INANGOPLUG_DPID}")"; then
        echo "${response}"
        return 0
    else
        return 1
    fi
}

inangoplug_register()
{
    local inangoplug_register_response=

    if [ -z "${INANGOPLUG_DPID}" ] || [ -z "${INANGOPLUG_SO_SERV}" ]; then
        return 1
    fi

    echo "-------- register board in INANGOPLUG setup --------"

    inangoplug_register_response="$(reg_agent)"|| { echo "Can't register Inango Plug, exiting..." && exit $EXIT_RESTART; }
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

# Returns none if certificate file is not valid
# Returns path to file if certificate file is valid (one of runtime or default)
validate_certificates_files()
{
    if [ -f $1 ]; then
        if [ -s $1 ]; then
            echo $1
            return
        fi
        echo "none"
    elif [ -s $2 ]; then
        echo $2
    else
        echo "none"
    fi
}

init_certificates_var() {
    INANGOPLUG_SC_PRIVKEY="$(validate_certificates_files \
                             ${CONFIG_OVS_INFRASTRUCTURE_SSL_RUNTIME_DIR}${INANGOPLUG_SC_PRIVKEY} \
                             ${CONFIG_OVS_INFRASTRUCTURE_SSL_DEFAULT_DIR}${INANGOPLUG_SC_PRIVKEY})"
    if [ "$INANGOPLUG_SC_PRIVKEY" = "none" ]; then
        echo "File sc-privkey.pem is invalid, choose tcp..."
        return 1
    fi

    INANGOPLUG_SC_CERT="$(validate_certificates_files \
                          ${CONFIG_OVS_INFRASTRUCTURE_SSL_RUNTIME_DIR}${INANGOPLUG_SC_CERT} \
                          ${CONFIG_OVS_INFRASTRUCTURE_SSL_DEFAULT_DIR}${INANGOPLUG_SC_CERT})"
    if [ "$INANGOPLUG_SC_CERT" = "none" ]; then
        echo "File sc-cert.pem is invalid, choose tcp..."
        return 1
    fi

    INANGOPLUG_CA_CERT="$(validate_certificates_files \
                          ${CONFIG_OVS_INFRASTRUCTURE_SSL_RUNTIME_DIR}${INANGOPLUG_CA_CERT} \
                          ${CONFIG_OVS_INFRASTRUCTURE_SSL_DEFAULT_DIR}${INANGOPLUG_CA_CERT})"

    INANGOPLUG_OVS_PROTO="ssl"
    return 0
}

check_for_internet() {
    if  ping -q -c 1 -W 1 ${INANGOPLUG_SO_SERV}  > /dev/null && [ -f /sys/class/net/${INANGOPLUG_MAC_SRC_IF_NAME}/address ]; then
        return 0
    else
        return 1
    fi
}

check_inango_so_serv_addr() {
    if [ -z "${INANGOPLUG_SO_SERV}" ]
    then
        return 1
    fi
    return 0
}

check_for_wan_address() {
    echo "Check for ${INANGOPLUG_MAC_SRC_IF_NAME} mac address..."

    if [ "$(sysevent get docsis-initialized)" == "1" ]; then
        return 0
    elif [ "$(sysevent get eth_wan_mac)" != "" ]; then
        return 0
    else
        return 1
    fi
}

check_for_bridge() {
    echo "Check for ${BR_NAME} bridge..."

    if ${INANGOPLUG_OVS_CTL} show | grep -q ${BR_NAME}; then
        return 0
    else
        return 1
    fi
}

reset_bridge() {
    # Remove old controller and manager addresses
    ${INANGOPLUG_OVS_CTL} del-controller ${BR_NAME}
    ${INANGOPLUG_OVS_CTL} del-manager
}
###
##  ~ Main chunk
###

check_for_wan_address || { echo "Couldn't get wan address" && exit $EXIT_RESTART; }

INANGOPLUG_DPID="$(get_dpid)"

check_for_bridge || { echo "Couldn't get bridge ${BR_NAME}" && exit $EXIT_RESTART; }

set_datapath_id

reset_bridge

check_inango_so_serv_addr || { echo "Inango SO server is not set" && exit $EXIT_NO_RESTART; }

init_certificates_var && set_ssl_certificates

check_for_internet || { echo "Don't get internet connection" && exit $EXIT_RESTART; }

INANGOPLUG_RESPONSE="$(inangoplug_register)" || { echo "Registration on Inango SO platform failed" && exit $EXIT_RESTART; }

# Getting openflow host and port from INANGOPLUG json response
resolve_controllers || { echo "Failed to get OpenFlow Controller or Manager..." && exit $EXIT_RESTART; }

configure_bridge
