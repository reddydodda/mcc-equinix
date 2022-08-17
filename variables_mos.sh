#!/bin/bash

###############
# variables
###############
# Same as METAL_AUTH_TOKEN
export SET_EQUINIX_USER_API_TOKEN="${METAL_AUTH_TOKEN}"
# Same as TF_VAR_project_id
export SET_EQUINIX_PROJECT_ID="${TF_VAR_project_id}"
# Same as Metro code from step 3
export EQUINIX_FACILITY=da11
# Equinx project ssh key
export EQUINIX_SSH_KEY_NAME="cdodda_key"

###############
# Networking
###############
export SET_EQUINIX_VLAN_ID="1001"
export SET_FIP_VLAN_ID="1002"

export SET_LB_HOST="192.168.1.10"
export SET_EQUINIX_METALLB_RANGES="192.168.1.30-192.168.1.49"
export SET_EQUINIX_NETWORK_CIDR="192.168.1.0/24"
export SET_EQUINIX_NETWORK_GATEWAY="192.168.1.1"
export SET_EQUINIX_NETWORK_DHCP_RANGES="192.168.1.11-192.168.1.19"
export SET_EQUINIX_CIDR_INCLUDE_RANGES="192.168.1.20-192.168.1.29"
export SET_EQUINIX_CIDR_EXCLUDE_RANGES="192.168.1.51-192.168.1.250"

export SET_EQUINIX_NETWORK_NAMESERVERS="192.168.0.1"

##############

export CLUSTER_RELEASE=mosk-8-8-0-22-3
export CLUSTER_NAME=mostest
export NAMESPACE=mos
export DEDICATED_CONTROL_PLANE=true

###############
# node count
###############
export CMP_NODES=3
export EQUINIX_MACHINE_TYPE_MASTER=c3.small.x86
export EQUINIX_MACHINE_TYPE_CTL=c3.small.x86
export EQUINIX_MACHINE_TYPE_CMP=s3.xlarge.x86
#############
#ceph
#############
export CEPH_MANUAL_CONFIGURATION="True"
export SET_CEPH_DISK_CLASS="hdd"
