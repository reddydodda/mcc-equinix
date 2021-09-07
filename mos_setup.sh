#!/bin/bash

if [ -z "$1" ]
then
        cloud_name="mos"
else
        cloud_name=$1
fi

home_dir=$PWD/${cloud_name}
kaas_dir=$PWD

export KUBECONFIG=${kaas_dir}/mcc/kaas-bootstrap/kubeconfig
source ${kaas_dir}/variables_mos.sh

kubectl create ns $NAMESPACE

kubectl get publickey -o yaml bootstrap-key | sed "s|namespace: default|namespace: $NAMESPACE|" | kubectl apply -f -

kubectl apply -f ${home_dir}/equinix-config.yaml
sleep 15
kubectl apply -f ${home_dir}/cluster.yaml
sleep 10
kubectl apply -f ${home_dir}/machines_master.yaml
sleep 15
kubectl apply -f ${home_dir}/machines_ctl.yaml
sleep 15
kubectl apply -f ${home_dir}/machines_cmp.yaml

echo "Completed"
