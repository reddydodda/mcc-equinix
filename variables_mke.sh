#!/bin/bash

###############
# variables
###############
export API_TOKEN="<<API_TOKEN>>"
export PROJECT_ID="<<PROJECT_ID>>"
export PACKET_TOKEN="<<PACKET_TOKEN>>"
export EQUINIX_FACILITY=am6
export EQUINIX_MACHINE_TYPE_MASTER=c3.small.x86
export EQUINIX_MACHINE_TYPE_WORKER=c3.medium.x86
export MACHINES_AMOUNT=9

###
export CLUSTER_RELEASE=mke-7-0-0-3-4-0
export CLUSTER_NAME=mke01
export NAMESPACE=mke
export DEDICATED_CONTROL_PLANE=true

###
export WORKER_NODES=5
