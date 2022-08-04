#!/bin/bash

########################
# Bootstrap the node

# sudo apt update; sudo apt install docker.io ipmitool bridge-utils -y
###############
# kaas binary
###############
cloud_name="mcc"

home_dir=$PWD/${cloud_name}
kaas_dir=$PWD

rm -rf ${home_dir}/kaas-bootstrap
mkdir -p ${home_dir}

wget https://binary.mirantis.com/releases/get_container_cloud.sh -O $home_dir/get_container_cloud.sh
chmod 0755 $home_dir/get_container_cloud.sh

cd $home_dir
./get_container_cloud.sh

mkdir $home_dir/kaas-bootstrap/templates.backup
cp -r $home_dir/kaas-bootstrap/templates/*  $home_dir/kaas-bootstrap/templates.backup/

#git add *
#git commit -m "Changes for ${cloud_name}"

#############################
# copy licence and templates
#############################

cp ${kaas_dir}/kaas/mirantis.lic $home_dir/kaas-bootstrap/
cp -r ${kaas_dir}/kaas/equinix/ $home_dir/kaas-bootstrap/templates/
##
source ${kaas_dir}/variables_mcc.sh
###################
# Update templates
###################

sed -i "s|EQUINIX_FACILITY|${EQUINIX_FACILITY}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_VLAN_ID|${SET_EQUINIX_VLAN_ID}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_LB_HOST|${SET_LB_HOST}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_METALLB_RANGES|${SET_EQUINIX_METALLB_RANGES}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_NETWORK_CIDR|${SET_EQUINIX_NETWORK_CIDR}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_NETWORK_GATEWAY|${SET_EQUINIX_NETWORK_GATEWAY}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_NETWORK_DHCP_RANGES|${SET_EQUINIX_NETWORK_DHCP_RANGES}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_CIDR_INCLUDE_RANGES|${SET_EQUINIX_CIDR_INCLUDE_RANGES}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_CIDR_EXCLUDE_RANGES|${SET_EQUINIX_CIDR_EXCLUDE_RANGES}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_NETWORK_NAMESERVERS|${SET_EQUINIX_NETWORK_NAMESERVERS}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
sed -i "s|SET_EQUINIX_NTP_SERVER|${SET_EQUINIX_NTP_SERVER}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template


sed -i "s|SET_EQUINIX_PROJECT_ID|${SET_EQUINIX_PROJECT_ID}|g" $home_dir/kaas-bootstrap/templates/equinixv2/equinix-config.yaml.template
sed -i "s|SET_EQUINIX_USER_API_TOKEN|${SET_EQUINIX_USER_API_TOKEN}|g" $home_dir/kaas-bootstrap/templates/equinixv2/equinix-config.yaml.template
sed -i "s|EQUINIX_MACHINE_TYPE|${EQUINIX_MACHINE_TYPE}|g" $home_dir/kaas-bootstrap/templates/equinixv2/machines.yaml.template


############
# SSH key
############
sed -i "s|BOOTSTRAP_SSH_PUBLIC_KEY|${BOOTSTRAP_SSH_PUBLIC_KEY}|g" $home_dir/kaas-bootstrap/templates/equinixv2/cluster.yaml.template
###################
# bootstrap.env
###################
cat << EOF >> $home_dir/kaas-bootstrap/bootstrap.env
export KAAS_BM_PXE_BRIDGE=${KAAS_BM_PXE_BRIDGE}
export KAAS_BM_PXE_IP=${KAAS_BM_PXE_IP}
export KAAS_BM_PXE_MASK=${KAAS_BM_PXE_MASK}
export BOOTSTRAP_METALLB_ADDRESS_POOL=${SET_EQUINIX_METALLB_RANGES}
export KAAS_EQUINIXMETALV2_ENABLED=true
export KAAS_BOOTSTRAP_DEBUG="${KAAS_BOOTSTRAP_DEBUG}"
EOF


echo "Completed Changes"
