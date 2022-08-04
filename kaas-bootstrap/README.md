# Mirantis KaaS Bootstrap

Release artifacts:

* Linux: https://binary.mirantis.com/core/bin/bootstrap-linux-1.32.6.tar.gz
* macOS: https://binary.mirantis.com/core/bin/bootstrap-darwin-1.32.6.tar.gz

## Prerequisites

### OS

We support the following operating systems:

* Ubuntu 18.04 - is fully tested, the bootstrap process is thoroughly verified on
  clean VM
* Ubuntu 16.04 - best effort, should be mostly working but can have some issues
  with outdated package versions
* MacOS - bootstrap is verified on engineer's laptops, no cleanroom testing

Overall bootstrap process is not very OS-dependent, only prerequisites are.

### Docker

You should install a recent version of Docker on your machine. For example,
Ubuntu 16.04 and 18.04 users could run:

  ```bash
  sudo apt install docker.io
  ```

Make sure it installs recent version of Docker (18.09.x is enough). Then grant
your user access to Docker daemon:

  ```bash
  sudo usermod -aG docker $USER
  ```

and re-login for these settings to be applied.

If you run on macOS, you should follow the steps in [official documentation](https://docs.docker.com/docker-for-mac/install/).
You should set at least 4 CPU and 2 GB RAM in Docker for Mac preferences on Advanced tab.

Now check that network setup works fine for your cloud. For example, for internal EU cloud, run:

  ```bash
  docker run --rm alpine sh -c "apk add --no-cache curl; curl https://ic-eu.ssl.mirantis.net:5000"
  ```

You should get some JSON in output, with no errors. If it fails, try following fixes.

#### Default network addresses

Related curl error: either curl hangs or `curl: (7) Failed to connect to xxx.xxx.xxx.xxx port 5000: Host is unreachable`

If default Docker network `172.17.0.0/16` overlaps with address of your cloud or
other addresses in your network configuration, you must change IP address for default
Docker bridge. To do this on Ubuntu, create or edit file `/etc/docker/daemon.json` and add to it:

  ```json
  {
    "bip": "192.168.91.1/24"
  }
  ```

After this, restart Docker daemon:

  ```bash
  sudo systemctl restart docker
  ```

On macOS, go to Docker preferences, there select Daemon/Advanced and add this
value to JSON in the text field and press "Apply & Restart" button.

#### DNS settings

Related curl error: `curl: (6) Could not resolve host`

If you're using a VPN to connect to the cloud or you have local DNS forwarder set up,
you might need to change default DNS settings for Docker. This usually is not a problem for macOS.

To do this, you need to find out which DNS server do you need and add it to `/etc/docker/daemon.json`:

  ```json
  {
    "dns": ["<INSERT DNS ADDRESS HERE>"]
  }
  ```

Note that DNS addresses differ in different locations.

## OpenStack credentials

1. Log into your OpenStack Horizon
2. Under "Project" select "API Access"
3. In dropdown to the right "Download OpenStack RC File" select "OpenStack clouds.yaml File"
4. Put resulting clouds.yaml file into the directory with bootstrap.sh script
<aside class="warning">
Manually written custom `clouds.yaml` file may not work as expected
</aside>
5. Edit `clouds.yaml` file and add “password” field under “clouds/openstack/auth”
   section with your OpenStack password. Final `clouds.yaml` file should look like this:

   ```yaml
   clouds:
     openstack:
       auth:
         auth_url: https://ic-eu.ssl.mirantis.net:5000/v3 # for EU cloud
         username: someusername # your username
         password: yoursecretpassword # your password - add this field
         project_id: 0123456789abcdef0123456789abcdef # your project ID
         user_domain_name: ldap-password # for LDAP users, default for service ones
       region_name: RegionOne
       interface: public
       identity_api_version: 3
   ```

## vSphere credentials

1. Edit `vsphere-config.yaml.template` file inside templates/vsphere folder according to documentation


## Adjust templates to your requirements

1. In `templates/cluster.yaml.template` set preferrable `dnsNameservers` (default value `172.18.224.6`
   is for internal US cloud, for EU cloud use `172.18.176.6`).
2. In `templates/machines.yaml.template` you can change flavor, image and availabilityZone,
   defaults should work fine for both US and EU clouds.

## Run bootstrap process

Now that everything is ready, run:

  ```bash
  ./bootstrap.sh all
  ```

to go through all bootstrap steps. In the end, it should provide you with URL for KaaS UI
and the credentials to log into it. Config for kubectl with admin credentials for the cluster
will also be saved in the `kubeconfig` file.

## Troubleshooting

In case of deployment problems, the first step is to dump all logs:

  ```bash
  ./bootstrap.sh collect_logs
  ```

It will collect bootstrap and management cluster logs/events.

<aside class="warning">
Use this command before `Cleanup` operations
</aside>


## Cleanup

After you're done with the bootstrapped cluster, first delete all clusters created using it, then run:

  ```bash
  ./bootstrap.sh cleanup
  ```

It will delete all resources occupied by the KaaS and its own cluster.
