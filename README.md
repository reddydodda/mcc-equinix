## On Seed Node

1. Download trail Licence for MCC:

    https://www.mirantis.com/software/docker/docker-enterprise-container-cloud/download/

2. Install Docker

```shell
sudo apt install docker.io

sudo usermod -aG docker $USER
```

## Precheck:

1. Create new account in Equinix

    get below details from it: ( https://docs.mirantis.com/container-cloud/latest/qs-equinix/conf-bgp.html )
    ```shell
    API_TOKEN=
    PROJECT_ID=
    ```
2. check max_prefix BGP parameter ( min 150 should be the value )

    ```shell
    curl -sS -H "X-Auth-Token: ${API_TOKEN}" "https://api.equinix.com/metal/v1/projects/${PROJECT_ID}/bgp-config" | jq .max_prefix
    ```

3. Check if capacity available 

    ```shell
    ./tools/packet-cli capacity check --facility am6 --plan c3.small.x86 --quantity 6
     ```
 


## Deploy MCC-Mgmt Cluster

```shell

1. git clone https://github.com/reddydodda/mcc-equinix.git

2. cd equinix/

3. update  variables_mcc.sh

4. Generate templates for MCC

   ./mcc_templates.sh

5. Update MCC License file with demo License got from Step1

   vim mcc/kaas-bootstrap/mirantis.lic

5. deploy mcc-mgmt cluster

   cd mcc/kaas-bootstrap/

   ./bootstrap.sh all

## Check deployment status

1. get machine status

   kubectl --kubeconfig ~/.kube/kind-config-clusterapi get lcmmachines -o wide

2. get KAAS UI from 

   kubectl -n kaas get svc kaas-kaas-ui

3. create MCC user

   export KUBECONFIG=$PWD/mcc/kaas-bootstrap/kubeconfig
   
   ./mcc/kaas-bootstrap/kaas bootstrap user add --username writer --roles writer
   ./mcc/kaas-bootstrap/kaas bootstrap user add --username reader --roles reader


```

## Deploy MKE Child cluster

```shell

1. update variables_mke.sh

2. generate templates for mke

  ./mke_templates.sh mke

3. deploy child MKE

  ./mke_setup.sh mke

4. check machine and lcmmachine status 

  export KUBECONFIG=$PWD/mcc/kaas-bootstrap/kubeconfig

  kubectl -n mke get lcmmachines -o wide
 
5. once deployment is completed, download kubeconfig token from MCC UI

7. Create a ceph cluster on top of the existing Kubernetes cluster:

  export KUBECONFIG=$PWD/mcc/kaas-bootstrap/kubeconfig

  kubectl apply -f $HOME/mke/kaascephcluster.yaml

8. Wait until all resources are up and running on the child cluster.

  kubectl get pods -n rook-ceph
  ```
  
 ## Deploy MOS Child cluster

 ### Deploy MKE child cluster and Ceph for MOS 
 
```shell

1. update variables_mos.sh

2. generate templates for mos

  ./mos_templates.sh mos

3. deploy child MKE cluster for MOS

  ./mos_setup.sh mos

4. check machine and lcmmachine status 

  export KUBECONFIG=$PWD/mcc/kaas-bootstrap/kubeconfig

  kubectl -n mos get lcmmachines -o wide
 
5. once deployment is completed, download kubeconfig token from MCC UI

7. Create a ceph cluster on top of the existing Kubernetes cluster:

  export KUBECONFIG=$PWD/mcc/kaas-bootstrap/kubeconfig

  kubectl apply -f $HOME/mos/kaascephcluster.yaml

8. Wait until all resources are up and running on the child cluster.

  kubectl get pods -n rook-ceph

9. Check Ceph deployment status before starting the OpenStack deployment: 

  export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig

  kubectl exec -itn rook-ceph $(kubectl get po -n rook-ceph -l app=rook-ceph-tools -o jsonpath={.items[*].metadata.name}) -- ceph -s

  kubectl get miracephlog rook-ceph -n ceph-lcm-mirantis -o yaml

10. Also check for OpenStack ceph keyrings before moving with MOS deployment:

  export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig

  kubectl get secret -n openstack-ceph-shared openstack-ceph-keys
```

### Update Node networking 

```shell
1. Login to Equinix console and navigate to “IPs & Networks -> Layer2” :  Create new VLAN as below

    a. Location: AM, Description: mos-tenant, VNID: 100
    b. Location: AM, Description: mos-floatingip, VNID: 101
    
2. Next update node network to use network type as Hybrid ( no bonding mode ) : 

    Navigate to “Servers -> $Node_name> -> Network -> Convert to Other NetworkType -> Hybride” 

    then click on "Convert to Hybride Networking" button.

Note: to get the $node_name info use, kubectl get lcmmachines -n mos -o wide 

3. on same tab ( Network ) scroll down to add vlan to the server :  

    Layer2 -> Add New Vlan -> Interface ( eth1 ) -> mos-tenant , mos-floatingip
    
    Click on Add button.
    
4. SSH to MOS nodes ( Control and CMP nodes ) and change interface file to have new vlan and also remove interface from bond

    ssh -i ssh_key mcc-user@NODE_IP
    
    ## Install vlan packages and load modules 
    sudo apt-get install vlan
    sudo modprobe 8021q
    sudo echo "8021q" >> /etc/modules
    echo "-enp216s0f1" > /sys/class/net/bond0/bonding/slaves
    sudo ifdown enp216s0f1

    ## Update interface file to have new vlan
    sudo vim /etc/network/interfaces 

    auto enp216s0f1.100
    iface enp216s0f1.100 inet static
         address 192.168.100.10
         netmask 255.255.255.0
         vlan-raw-device enp216s0f1
   
    auto enp216s0f1.101
    iface enp216s0f1.101 inet manual
         vlan-raw-device enp216s0f1  

    ## up the interface
    sudo ifup enp216s0f1

```

### Deploy MOS on MKE

```shell
1. Login to the seed node and configure the OsDpl resource depending on the needs of your deployment. Refer to below doc for more advanced resource

    https://docs.mirantis.com/mos/latest/ref-arch/openstack/openstack-operator/osdpl-cr.html

2. use Example osdpl file located at below path

    $PWD/mos/openstack.yaml
    
3. Trigger the OpenStack deployment (osdpl):

    export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig
    kubectl apply -f $HOME/mos/openstack.yaml

4. Check for openstack pods status

    export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig
    kubectl -n openstack get pods | grep 0/. | grep -v Completed | grep -v image


5. Check the current status of the OpenStack deployment using the status section output in the OsDpl resource.

    export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig
    kubectl -n openstack get osdpl osh-dev -o yaml | grep status


6. Verify that the OpenStack cluster has been deployed:

    export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig
    clinet_pod_name=$(kubectl -n openstack get pods -l application=keystone,component=client  | grep keystone-client | head -1 | awk '{print $1}')
    kubectl -n openstack exec -it $clinet_pod_name -- openstack service list


7. Access MOS after deployment:

    https://docs.mirantis.com/mos/latest/deployment-guide/deploy-openstack/access-openstack.html

    To obtain the full list of public endpoints:
    export KUBECONFIG=$HOME/mos/child_cluster_kubeconfig 

    ## To Get Ingress IP address
    kubectl -n openstack get services ingress

    ## TO get DNS records
    kubectl -n openstack get ingress -ocustom-columns=NAME:.metadata.name,HOSTS:spec.rules[*].host | awk '/fqdn/ {print $2}'
```
