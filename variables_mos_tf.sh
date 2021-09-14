#!/bin/bash

###############
# variables
###############
export API_TOKEN="<<API_TOKEN>>"
export PROJECT_ID="<<PROJECT_ID>>"
export PACKET_TOKEN="<<PACKET_TOKEN>>"
export EQUINIX_FACILITY=am6
export EQUINIX_MACHINE_TYPE_MASTER=c3.small.x86
export EQUINIX_MACHINE_TYPE_CTL=c3.medium.x86
export EQUINIX_MACHINE_TYPE_TFCTL=c3.medium.x86
export EQUINIX_MACHINE_TYPE_CMP=s3.xlarge.x86

###
export CLUSTER_RELEASE=mos-6-16-0-21-3
export CLUSTER_NAME=mostest
export NAMESPACE=mos
export DEDICATED_CONTROL_PLANE=true

###
export CMP_NODES=3
