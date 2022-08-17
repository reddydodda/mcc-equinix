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
# This need to be ssh key name created in equinx
export EQUINIX_SSH_KEY_NAME="cdodda_equinx_key"

##################
# Networking
##################
export SET_EQUINIX_VLAN_ID="1000"

export KAAS_BM_PXE_BRIDGE="br0"
export KAAS_BM_PXE_IP="192.168.0.5"
export KAAS_BM_PXE_MASK="24"

export SET_LB_HOST="192.168.0.10"
export SET_EQUINIX_METALLB_RANGES="192.168.0.200-192.168.0.240"
export SET_EQUINIX_NETWORK_CIDR="192.168.0.0/24"
export SET_EQUINIX_NETWORK_GATEWAY="192.168.0.1"
export SET_EQUINIX_NETWORK_DHCP_RANGES="192.168.0.11-192.168.0.49"
export SET_EQUINIX_CIDR_INCLUDE_RANGES="192.168.0.51-192.168.0.99"
export SET_EQUINIX_CIDR_EXCLUDE_RANGES="192.168.0.1-192.168.0.50"
export SET_EQUINIX_NETWORK_NAMESERVERS="147.75.207.208"
export SET_EQUINIX_NTP_SERVER="192.168.0.1"

