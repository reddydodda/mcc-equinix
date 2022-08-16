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

##################
# Networking
##################
export SET_EQUINIX_VLAN_ID="1001"
export SET_LB_HOST="192.168.1.10"
export SET_EQUINIX_METALLB_RANGES="192.168.1.30-192.168.1.49"
export SET_EQUINIX_NETWORK_CIDR="192.168.1.0/24"
export SET_EQUINIX_NETWORK_GATEWAY="192.168.1.1"
export SET_EQUINIX_NETWORK_DHCP_RANGES="192.168.1.11-192.168.1.19"
export SET_EQUINIX_CIDR_INCLUDE_RANGES="192.168.1.20-192.168.1.29"
export SET_EQUINIX_CIDR_EXCLUDE_RANGES="192.168.1.51-192.168.1.250"

###
export CLUSTER_RELEASE=mke-11-3-0-3-5-3
export CLUSTER_NAME=mke01
export NAMESPACE=mke
export DEDICATED_CONTROL_PLANE=true

#########
# nodes
#########
export EQUINIX_MACHINE_TYPE_MASTER="c3.small.x86"
export EQUINIX_MACHINE_TYPE_WORKER="c3.small.x86"
export WORKER_NODES=3

##########
# ceph
#########
export CEPH_MANUAL_CONFIGURATION="False"
