#!/bin/bash

########################
# Bootstrap the node

# sudo apt update; sudo apt install docker.io ipmitool bridge-utils -y
###############
# kaas binary
###############
if [ -z "$1" ]
then
	cloud_name="mos"
else
	cloud_name=$1
fi

home_dir=$PWD/${cloud_name}
kaas_dir=$PWD

mkdir -p ${home_dir}

cp -r ${kaas_dir}/kaas/mos/* $home_dir
source ${kaas_dir}/variables_mos.sh
###################
# Update templates
###################
sed -i "s|EQUINIX_FACILITY|${EQUINIX_FACILITY}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_PROJECT_ID|${SET_EQUINIX_PROJECT_ID}|g" $home_dir/equinix-config.yaml
sed -i "s|SET_EQUINIX_USER_API_TOKEN|${SET_EQUINIX_USER_API_TOKEN}|g" $home_dir/equinix-config.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_MASTER|${EQUINIX_MACHINE_TYPE_MASTER}|g" $home_dir/machines_master.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_CTL|${EQUINIX_MACHINE_TYPE_CTL}|g" $home_dir/machines_ctl.yaml
sed -i "s|EQUINIX_MACHINE_TYPE_CMP|${EQUINIX_MACHINE_TYPE_CMP}|g" $home_dir/machines_cmp.yaml

sed -i "s|CLUSTER_NAME|${CLUSTER_NAME}|g" $home_dir/*
sed -i "s|NAMESPACE|${NAMESPACE}|g" $home_dir/*
sed -i "s|CLUSTER_RELEASE|${CLUSTER_RELEASE}|g" $home_dir/cluster.yaml
sed -i "s|DEDICATED_CONTROL_PLANE|${DEDICATED_CONTROL_PLANE}|g" $home_dir/cluster.yaml

sed -i "s|EQUINIX_SSH_KEY_NAME|${EQUINIX_SSH_KEY_NAME}|g" $home_dir/cluster.yaml

###################
# Networking 
###################
sed -i "s|SET_EQUINIX_VLAN_ID|${SET_EQUINIX_VLAN_ID}|g" $home_dir/*.yaml
sed -i "s|SET_FIP_VLAN_ID|${SET_FIP_VLAN_ID}|g" $home_dir/*.yaml

sed -i "s|SET_LB_HOST|${SET_LB_HOST}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_METALLB_RANGES|${SET_EQUINIX_METALLB_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_NETWORK_CIDR|${SET_EQUINIX_NETWORK_CIDR}|g" $home_dir/*.yaml
sed -i "s|SET_EQUINIX_NETWORK_GATEWAY|${SET_EQUINIX_NETWORK_GATEWAY}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_NETWORK_DHCP_RANGES|${SET_EQUINIX_NETWORK_DHCP_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_CIDR_INCLUDE_RANGES|${SET_EQUINIX_CIDR_INCLUDE_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_CIDR_EXCLUDE_RANGES|${SET_EQUINIX_CIDR_EXCLUDE_RANGES}|g" $home_dir/cluster.yaml
sed -i "s|SET_EQUINIX_NETWORK_NAMESERVERS|${SET_EQUINIX_NETWORK_NAMESERVERS}|g" $home_dir/cluster.yaml

################
# ceph changes
################

sed -i "s|SET_CEPH_DISK_CLASS|${SET_CEPH_DISK_CLASS}|g" $home_dir/*.yaml
sed -i "s|CEPH_MANUAL_CONFIGURATION|${CEPH_MANUAL_CONFIGURATION}|g" $home_dir/cluster.yaml

###################
# Machine changes
###################


count=1
while [ $count -lt $CMP_NODES ]; do
	
((count++))

cat << EOF >> $home_dir/machines_cmp.yaml
- apiVersion: "cluster.k8s.io/v1alpha1"
  kind: Machine
  metadata:
    name: $CLUSTER_NAME-cmp-0$count
    namespace: $NAMESPACE
    labels:
      kaas.mirantis.com/provider: equinixmetalv2
      kaas.mirantis.com/region: region-one
      cluster.sigs.k8s.io/cluster-name: $CLUSTER_NAME
  spec: *cp_spec
EOF

if [ "${CEPH_MANUAL_CONFIGURATION}" = true ] || [ "${CEPH_MANUAL_CONFIGURATION}" = True ]; then
cat << EOF >> $home_dir/kaascephcluster.yaml
      $CLUSTER_NAME-cmp-0$count:
        storageDevices:
        - name: sdc
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme0n1
        - name: sdd
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme0n1
        - name: sde
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme0n1
        - name: sdf
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme0n1
        - name: sdg
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme0n1
        - name: sdh
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme0n1
        - name: sdi
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme1n1
        - name: sdj
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme1n1
        - name: sdk
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme1n1
        - name: sdl
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme1n1
        - name: sdm
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme1n1
        - name: sdn
          config:
            osdsPerDevice: "1"
            deviceClass: ${SET_CEPH_DISK_CLASS}
            metadataDevice: nvme1n1
EOF
fi

done

echo "Completed Changes"
