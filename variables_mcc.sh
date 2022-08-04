#!/bin/bash

###############
# variables
###############
export SET_EQUINIX_USER_API_TOKEN="<<USER_API_TOKEN>>"
export SET_EQUINIX_PROJECT_ID="<<PROJECT_ID>>"
export EQUINIX_FACILITY=am6
export EQUINIX_MACHINE_TYPE=c3.small.x86
export MACHINES_COUNT=3
#######################
# Network parameters
#######################
subnet_pxe=$(cat output.json | jq -r ".vlans.value.${EQUINIX_FACILITY}[].subnet" | awk -F "." '{print $1"."$2"."$3"}')

export SET_EQUINIX_VLAN_ID=$(cat output.json | jq -r ".vlans.value.${EQUINIX_FACILITY}[].vlan_id")

export KAAS_BM_PXE_BRIDGE="br0"
export KAAS_BM_PXE_IP="${subnet_pxe}.5"
export KAAS_BM_PXE_MASK="24"
export KAAS_BOOTSTRAP_DEBUG=true

export SET_LB_HOST="${subnet_pxe}.10"
export SET_EQUINIX_METALLB_RANGES="${subnet_pxe}.200-${subnet_pxe}.240"
export SET_EQUINIX_NETWORK_CIDR="${subnet_pxe}.10/24"
export SET_EQUINIX_NETWORK_GATEWAY="${subnet_pxe}.1"
export SET_EQUINIX_NETWORK_DHCP_RANGES="${subnet_pxe}.11-${subnet_pxe}.49"
export SET_EQUINIX_CIDR_INCLUDE_RANGES="${subnet_pxe}.51-${subnet_pxe}.99"
export SET_EQUINIX_CIDR_EXCLUDE_RANGES="${subnet_pxe}.1-${subnet_pxe}.50"
export SET_EQUINIX_NETWORK_NAMESERVERS=""

export SET_EQUINIX_NTP_SERVER="${subnet_pxe}.1"

export BOOTSTRAP_SSH_PUBLIC_KEY="ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAAGIkGMhjAj+42V3+tq+Iq7oPk3Z6i2zEGGFW010MI2u2FpPY9uaJoNKtN4i/iZnBZRmCBohN6unfg5MbpsopFhPAGdfF05hJOueaCujLuiWRh7TtUu7TH5nQL7JzE7ER0HLV7N+aIg6yVSCrPGblwASCNTtSntRXxBMIOOmP+5d4meVg=="
