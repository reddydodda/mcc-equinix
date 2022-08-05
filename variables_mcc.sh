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
