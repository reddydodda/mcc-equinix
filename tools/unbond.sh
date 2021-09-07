#!/bin/bash

source $PWD/variables_mos.sh

export KUBECONFIG=$PWD/mcc/kaas-bootstrap/kubeconfig

for (( i=1; i<=$CMP_NODES; i++ )) do
        public_ip=$(kubectl get machines -n mos mostest-cmp-0$i -o json | jq -r ".status.providerStatus.publicIp")
        #server_id=$(kubectl get machines -n mos mostest-cmp-0$i -o json | jq -r ".status.providerStatus.providerInstanceState.id")

echo $public_ip
## change interface file
ssh -i $PWD/mcc/kaas-bootstrap/ssh_key mcc-user@${public_ip} "int_name=$(cat /sys/class/net/bond0/bonding/slaves | awk '{print $2}'); sudo apt-get install vlan; sudo modprobe 8021q; echo "8021q" | sudo tee -a /etc/modules ; echo "-\${int_name}" | sudo tee -a /sys/class/net/bond0/bonding/slaves ; sudo ifdown \${int_name} ; sudo vconfig add \${int_name} 100; sudo vconfig add \${int_name} 101; sudo ip addr add 192.168.100.1${i}/24 dev \${int_name}.100; sudo ip addr add 192.168.101.1${i}/24 dev \${int_name}.101; sudo ifup \${int_name}"
done


for (( i=1; i<=3; i++ )) do
        public_ip=$(kubectl get machines -n mos mostest-ctl-0$i -o json | jq -r ".status.providerStatus.publicIp")
echo $public_ip

## change interface file
ssh -i $PWD/mcc/kaas-bootstrap/ssh_key mcc-user@${public_ip} "int_name=$(cat /sys/class/net/bond0/bonding/slaves | awk '{print $2}'); sudo apt-get install vlan; sudo modprobe 8021q; echo "8021q" | sudo tee -a /etc/modules ; echo "-\${int_name}" | sudo tee -a /sys/class/net/bond0/bonding/slaves ; sudo ifdown \${int_name} ; sudo vconfig add \${int_name} 100; sudo vconfig add \${int_name} 101; sudo ip addr add 192.168.100.2${i}/24 dev \${int_name}.100; sudo ip addr add 192.168.101.2${i}/24 dev \${int_name}.101; sudo ifup \${int_name}"
done
