#!/bin/bash
set -x
########################
# Bootstrap the node

# sudo apt update; sudo apt install docker.io ipmitool bridge-utils -y
###############
# kaas binary
###############
if [ -z "$1" ]
then
	cloud_name="mke"
else
	cloud_name=$1
fi

home_dir=$PWD/${cloud_name}
kaas_dir=$PWD

mkdir -p ${home_dir}

cp -r ${kaas_dir}/kaas/mke/* $home_dir
source ${kaas_dir}/variables_mke.sh
###################
# Update templates
###################

sed -i "s|EQUINIX_FACILITY|${EQUINIX_FACILITY}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_PROJECT_ID|${SET_EQUINIX_PROJECT_ID}|g" $home_dir/equinix-config.yaml
sed -i "s|SET_EQUINIX_USER_API_TOKEN|${SET_EQUINIX_USER_API_TOKEN}|g" $home_dir/equinix-config.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_MASTER|${EQUINIX_MACHINE_TYPE_MASTER}|g" $home_dir/machines_master.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_WORKER|${EQUINIX_MACHINE_TYPE_WORKER}|g" $home_dir/machines_worker.yaml

sed -i "s|CLUSTER_NAME|${CLUSTER_NAME}|g" $home_dir/*
sed -i "s|NAMESPACE|${NAMESPACE}|g" $home_dir/*
sed -i "s|CLUSTER_RELEASE|${CLUSTER_RELEASE}|g" $home_dir/cluster.yaml
sed -i "s|DEDICATED_CONTROL_PLANE|${DEDICATED_CONTROL_PLANE}|g" $home_dir/cluster.yaml

###################
# Networking 
###################
sed -i "s|SET_EQUINIX_VLAN_ID|${SET_EQUINIX_VLAN_ID}|g" $home_dir/cluster.yaml
sed -i "s|SET_LB_HOST|${SET_LB_HOST}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_METALLB_RANGES|${SET_EQUINIX_METALLB_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_NETWORK_CIDR|${SET_EQUINIX_NETWORK_CIDR}|g" $home_dir/*.yaml
sed -i "s|SET_EQUINIX_NETWORK_GATEWAY|${SET_EQUINIX_NETWORK_GATEWAY}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_NETWORK_DHCP_RANGES|${SET_EQUINIX_NETWORK_DHCP_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_CIDR_INCLUDE_RANGES|${SET_EQUINIX_CIDR_INCLUDE_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_CIDR_EXCLUDE_RANGES|${SET_EQUINIX_CIDR_EXCLUDE_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_NETWORK_NAMESERVERS|${SET_EQUINIX_NETWORK_NAMESERVERS}|g" $home_dir/cluster.yaml

###############
# worker nodes
###############
sed -i "s|CEPH_MANUAL_CONFIGURATION|${CEPH_MANUAL_CONFIGURATION}|g" $home_dir/cluster.yaml

count=1
while [ $count -lt $WORKER_NODES ]; do
	
((count++))

cat << EOF >> $home_dir/machines_worker.yaml
- apiVersion: "cluster.k8s.io/v1alpha1"
  kind: Machine
  metadata:
    name: $CLUSTER_NAME-worker-0$count
    namespace: $NAMESPACE
    labels:
      kaas.mirantis.com/provider: equinixmetalv2
      kaas.mirantis.com/region: region-one
      cluster.sigs.k8s.io/cluster-name: $CLUSTER_NAME
  spec: *cp_spec
EOF

if [ "${CEPH_MANUAL_CONFIGURATION}" = true ]; then
cat << EOF >> $home_dir/kaascephcluster.yaml
      $CLUSTER_NAME-worker-0$count:
        storageDevices:
        - name: sdb
          config:
            osdsPerDevice: "1"
            deviceClass: ssd
        - name: sdc
          config:
            osdsPerDevice: "1"
            deviceClass: ssd
EOF
fi

done

echo "Completed Changes"
