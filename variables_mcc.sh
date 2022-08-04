#!/bin/bash

kaas_dir=$PWD

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
export KAAS_BOOTSTRAP_DEBUG=true
export BOOTSTRAP_SSH_PUBLIC_KEY="ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAAGIkGMhjAj+42V3+tq+Iq7oPk3Z6i2zEGGFW010MI2u2FpPY9uaJoNKtN4i/iZnBZRmCBohN6unfg5MbpsopFhPAGdfF05hJOueaCujLuiWRh7TtUu7TH5nQL7JzE7ER0HLV7N+aIg6yVSCrPGblwASCNTtSntRXxBMIOOmP+5d4meVg=="
