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
## workaroud to fix PRODX-16254
cp -r ${kaas_dir}/kaas/workaround/6.16.0.yaml $home_dir/kaas-bootstrap/releases/cluster/6.16.0.yaml
##
source ${kaas_dir}/variables_mcc.sh
###################
# Update templates
###################

sed -i "s|EQUINIX_FACILITY|${EQUINIX_FACILITY}|g" $home_dir/kaas-bootstrap/templates/equinix/cluster.yaml.template
sed -i "s|PROJECT_ID|${PROJECT_ID}|g" $home_dir/kaas-bootstrap/templates/equinix/equinix-config.yaml.template
sed -i "s|API_TOKEN|${API_TOKEN}|g" $home_dir/kaas-bootstrap/templates/equinix/equinix-config.yaml.template
sed -i "s|EQUINIX_MACHINE_TYPE|${EQUINIX_MACHINE_TYPE}|g" $home_dir/kaas-bootstrap/templates/equinix/machines.yaml.template

###################
# bootstrap.env
###################
cat << EOF >> $home_dir/kaas-bootstrap/bootstrap.env
export KAAS_EQUINIX_ENABLED=true
export KAAS_BOOTSTRAP_DEBUG="${KAAS_BOOTSTRAP_DEBUG}"
EOF


echo "Completed Changes"
