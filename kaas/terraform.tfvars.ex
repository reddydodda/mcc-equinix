###################################
## Edge Node hostname
###################################
edge_hostname = "cdodda-mcc"

###################################
## Edge node type
###################################
edge_size = "c3.small.x86"

###################################
## Edge node OS
###################################
edge_os = "ubuntu_18_04"

###################################
## Absolute path to the private 
###################################
ssh_private_key_path = "/home/mirantis/mcc-equinix/ssh_key"

###################################
## Absolute path to the public 
###################################
ssh_public_key_path  = "/home/mirantis/mcc-equinix/ssh_key.pub"

###################################
# Metro code, vlans count
###################################
metros = [ { metro = "da" , vlans_amount = "2" , deploy_seed = "true" } ]

