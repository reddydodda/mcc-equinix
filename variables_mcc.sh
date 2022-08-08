#!/bin/bash

###############
# variables
###############
# Same as METAL_AUTH_TOKEN
export SET_EQUINIX_USER_API_TOKEN="${METAL_AUTH_TOKEN}"
# Same as TF_VAR_project_id
export SET_EQUINIX_PROJECT_ID="${TF_VAR_project_id}"
# Same as Metro code from step 3
export EQUINIX_FACILITY=da
# Use c3.small.x86 for MCC-Mgmt nodes
export EQUINIX_MACHINE_TYPE=c3.small.x86
# Machine count to check availability
export MACHINES_COUNT=6
# Enable debug
export KAAS_BOOTSTRAP_DEBUG=true
# Use same ssh key used for seed node
export BOOTSTRAP_SSH_PUBLIC_KEY="<<ssh_key>>"

##################
# Networking
##################

export SET_EQUINIX_VLAN_ID="<<VLAN_ID>>"

export KAAS_BM_PXE_BRIDGE="br0"
export KAAS_BM_PXE_IP="${subnet_pxe}.5"
export KAAS_BM_PXE_MASK="24"

export SET_LB_HOST="${subnet_pxe}.10"
export SET_EQUINIX_METALLB_RANGES="${subnet_pxe}.200-${subnet_pxe}.240"
export SET_EQUINIX_NETWORK_CIDR="${subnet_pxe}.10/24"
export SET_EQUINIX_NETWORK_GATEWAY="${subnet_pxe}.1"
export SET_EQUINIX_NETWORK_DHCP_RANGES="${subnet_pxe}.11-${subnet_pxe}.49"
export SET_EQUINIX_CIDR_INCLUDE_RANGES="${subnet_pxe}.51-${subnet_pxe}.99"
export SET_EQUINIX_CIDR_EXCLUDE_RANGES="${subnet_pxe}.1-${subnet_pxe}.50"
export SET_EQUINIX_NETWORK_NAMESERVERS="147.75.207.208"
export SET_EQUINIX_NTP_SERVER="${subnet_pxe}.1"

