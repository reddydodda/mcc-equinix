#!/bin/bash

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
sed -i "s|PROJECT_ID|${PROJECT_ID}|g" $home_dir/equinix-config.yaml
sed -i "s|API_TOKEN|${API_TOKEN}|g" $home_dir/equinix-config.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_MASTER|${EQUINIX_MACHINE_TYPE_MASTER}|g" $home_dir/machines_master.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_WORKER|${EQUINIX_MACHINE_TYPE_WORKER}|g" $home_dir/machines_worker.yaml

sed -i "s|CLUSTER_NAME|${CLUSTER_NAME}|g" $home_dir/*
sed -i "s|NAMESPACE|${NAMESPACE}|g" $home_dir/*
sed -i "s|CLUSTER_RELEASE|${CLUSTER_RELEASE}|g" $home_dir/cluster.yaml
sed -i "s|DEDICATED_CONTROL_PLANE|${DEDICATED_CONTROL_PLANE}|g" $home_dir/cluster.yaml

###################
# 
###################
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
      kaas.mirantis.com/provider: equinixmetal
      kaas.mirantis.com/region: region-one
      cluster.sigs.k8s.io/cluster-name: $CLUSTER_NAME
  spec: *cp_spec
EOF

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

done

echo "Completed Changes"
