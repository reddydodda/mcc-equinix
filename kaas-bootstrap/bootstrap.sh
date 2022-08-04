#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

if [ -f "${SCRIPT_DIR}/bootstrap.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/bootstrap.env"
fi

: "${KAAS_BOOTSTRAP_DEBUG:=}"
if [ -n "${KAAS_BOOTSTRAP_DEBUG}" ]; then
  : "${KAAS_BOOTSTRAP_LOG_LVL:=4}"
  set -x
fi
: "${COLLECT_EXTENDED_LOGS:=}"

: "${KAAS_BOOTSTRAP_LOG_LVL:=0}"
: "${KAAS_CMD:="${SCRIPT_DIR}/container-cloud"}"

# Set infinite timeout for all retry blocks and deploy stages in bootstrap
: "${KAAS_BOOTSTRAP_INFINITE_TIMEOUT:=}"
if [ -n "${KAAS_BOOTSTRAP_INFINITE_TIMEOUT}" ]; then
    INFINITE_TIMEOUT="true"
fi
: "${INFINITE_TIMEOUT:="false"}"

# Network to allocate floating IP from (name or ID)
: "${NETWORK:="public"}"

: "${KEYCLOAK_REALM:=iam}"

# Set true to use internal LB scheme for all MCC endpoints
: "${INTERNAL_LOAD_BALANCER:=false}"

: "${CUSTOM_HOSTNAMES:=false}"

: "${KAAS_USERNAME:=writer}"
: "${KAAS_PASSWORD:=password}"

: "${NAMESPACE:=kaas}"
: "${IAM_RELEASE_NAME:=iam}"
: "${KAAS_CDN_REGION:=internal-eu}"

: "${REGION:=}"
: "${REGIONAL_CLUSTER_NAME:=kaas-regional-"${REGION}"}"
: "${REGIONAL_CREDENTIALS_NAME:=cloud-config-"${REGION}"}"

: "${CHILD_CLUSTER_NAME:=kaas-child}"
: "${CHILD_CLUSTER_NAMESPACE:="${CHILD_CLUSTER_NAME}"}"
: "${CHILD_MACHINE_PREFIX:=kaas-child-machine}"
: "${CHILD_K8S_RELEASE_NAME:=kubernetes-3-6-0-rc-1-16}"
: "${CHILD_K8S_UPGRADE_RELEASE_NAME:=}"
: "${CLOUD_SECRET_NAME:=cloud-config}"

: "${KAAS_RELEASE_YAML:=}"
: "${CLUSTER_RELEASES_DIR:=}"

: "${BIN_DIR:="${SCRIPT_DIR}/bin"}"
: "${BOOTSTRAP_CLUSTER_NAME:="clusterapi"}"
: "${BOOTSTRAP_METALLB_ADDRESS_POOL:=}"

# KAAS-BM OPTS
: "${KAAS_BM_ENABLED:=}"
: "${KAAS_BM_FULL_PREFLIGHT:=}"
# Example: '172.10.10.10'
: "${KAAS_BM_PXE_IP:=}"
# Example: '26'
: "${KAAS_BM_PXE_MASK:=}"
# Example: 'br0'
: "${KAAS_BM_PXE_BRIDGE:=}"

: "${KAAS_BM_BM_DHCP_RANGE:=}"
# For internal testing only
: "${KAAS_NO_MGMT_CEPH:=}"

# KAAS-AWS OPTS
: "${KAAS_AWS_ENABLED:=}"
: "${AWS_SECRET_ACCESS_KEY:=}"
: "${AWS_ACCESS_KEY_ID:=}"
: "${AWS_DEFAULT_REGION:=us-east-2}"

# KAAS-VSPHERE OPTS
: "${KAAS_VSPHERE_ENABLED:=}"
# KAAS-VSPHERE PACKER OPTS
: "${VSPHERE_PACKER_ISO_FILE:=}"
: "${VSPHERE_PACKER_IMAGE_OS_NAME:="rhel"}"
: "${VSPHERE_PACKER_IMAGE_OS_VERSION:="7.9"}"
: "${VSPHERE_PACKER_DOCKER_IMAGE:="mirantis.azurecr.io/vsphere/packer-vmware:v1.0-47"}"
export VSPHERE_PACKER_DOCKER_IMAGE

# KAAS-EQUINIX OPTS
: "${KAAS_EQUINIX_ENABLED:=}"
: "${KAAS_EQUINIXMETALV2_ENABLED:=}"

# KAAS-AZURE OPTS
: "${KAAS_AZURE_ENABLED:=}"

: "${KIND_CMD:=${BIN_DIR}/kind}"
: "${KUBECTL_CMD:=${BIN_DIR}/kubectl}"

: "${OUT_DIR:="${SCRIPT_DIR}/out"}"
: "${LOG_DIR:="${SCRIPT_DIR}/logs"}"
: "${TEMPLATES_DIR:=""}"
# For internal testing only
: "${KAAS_CMDLINE_EQ2:=""}"
KAAS_CMDLINE_CEPHCLUSTER="--kaas-ceph-cluster-path ${OUT_DIR}/kaascephcluster.yaml"
if [ -n "${KAAS_NO_MGMT_CEPH}" ]; then
  KAAS_CMDLINE_CEPHCLUSTER=""
  KAAS_CMDLINE_EQ2="--disable-ceph"
fi

if [ -z "${TEMPLATES_DIR}" ]; then
# For usual case
  TEMPLATES_DIR="${SCRIPT_DIR}/templates"
# For kaas-bm case
  if [ -n "${KAAS_BM_ENABLED}" ]; then
    TEMPLATES_DIR="${SCRIPT_DIR}/templates/bm"
  fi
  if [ -n "${KAAS_AWS_ENABLED}" ]; then
    TEMPLATES_DIR="${SCRIPT_DIR}/templates/aws"
  fi
  if [ -n "${KAAS_VSPHERE_ENABLED}" ]; then
    TEMPLATES_DIR="${SCRIPT_DIR}/templates/vsphere"
  fi
  if [ -n "${KAAS_EQUINIX_ENABLED}" ]; then
    TEMPLATES_DIR="${SCRIPT_DIR}/templates/equinix"
  fi
  if [ -n "${KAAS_EQUINIXMETALV2_ENABLED}" ]; then
    TEMPLATES_DIR="${SCRIPT_DIR}/templates/equinixmetalv2"
  fi
  if [ -n "${KAAS_AZURE_ENABLED}" ]; then
    TEMPLATES_DIR="${SCRIPT_DIR}/templates/azure"
  fi
fi

: "${CHARTS_DIR:="${SCRIPT_DIR}/../charts"}"

: "${OS_CLIENT_CONFIG_FILE:="${SCRIPT_DIR}/clouds.yaml"}"
: "${OS_CLOUD:=openstack}"
export OS_CLIENT_CONFIG_FILE
export OS_CLOUD
: "${SSH_KEY_NAME:=bootstrap-key}"
: "${SSH_PRIVATE_KEY_PATH:="${SCRIPT_DIR}/ssh_key"}"

# DO NOT OVERWRITE default value for KUBECONFIG during `bootstrap` command run.
: "${KUBECONFIG:=kubeconfig}"
: "${CHILD_KUBECONFIG:="kubeconfig-${CHILD_CLUSTER_NAME}"}"
: "${REGIONAL_KUBECONFIG:="kubeconfig-${REGIONAL_CLUSTER_NAME}"}"
export KUBECONFIG

: "${CLUSTER_NAME:=kaas-mgmt}"

function _kind {
    if ! ${KIND_CMD} "$@"; then
        die "'$1' kind command failed"
    fi
}

function _kubectl {
    if ! ${KUBECTL_CMD} "$@"; then
        die "'$1' kubectl command failed"
    fi
}

function _kaas {
    env "PATH=${BIN_DIR}:$PATH" "${KAAS_CMD}" --v "${KAAS_BOOTSTRAP_LOG_LVL}" --infinite="${INFINITE_TIMEOUT}" "$@"
}

# Some useful colors.
if [[ -z "${color_start-}" ]]; then
    declare -r color_start="\033["
    declare -r color_red="${color_start}0;31m"
    declare -r color_yellow="${color_start}0;33m"
    declare -r color_green="${color_start}0;32m"
    declare -r color_norm="${color_start}0m"
fi

function logr {
    echo -e "${color_red}$1${color_norm}" 1>&2
}
function logy {
    echo -e "${color_yellow}$1${color_norm}" 1>&2
}
function log {
    echo -e "${color_green}$1${color_norm}" 1>&2
}
function die {
    logr "$1"
    exit 1
}

function ensure_command_exists {
    if ! hash "$1" 2>/dev/null ; then
        die "'$1' required and not installed"
    fi
}

function template_cluster {
    cp "${TEMPLATES_DIR}/cluster.yaml.template" "${OUT_DIR}/cluster.yaml"
    if [ -n "${KAAS_BM_ENABLED}" ]; then
      cp "${TEMPLATES_DIR}/baremetalhostprofiles.yaml.template" "${OUT_DIR}/baremetalhostprofiles.yaml"
      if [ -z "${KAAS_NO_MGMT_CEPH}" ]; then
        cp "${TEMPLATES_DIR}/kaascephcluster.yaml.template" "${OUT_DIR}/kaascephcluster.yaml"
      fi
      cp "${TEMPLATES_DIR}/ipam-objects.yaml.template" "${OUT_DIR}/ipam-objects.yaml"
    fi
    if [ -n "${KAAS_VSPHERE_ENABLED}" ]; then
      cp "${TEMPLATES_DIR}/vsphere-config.yaml.template" "${OUT_DIR}/vsphere-config.yaml"
    fi
    if [ -n "${KAAS_EQUINIX_ENABLED}" ] || [ -n "${KAAS_EQUINIXMETALV2_ENABLED}" ]; then
      cp "${TEMPLATES_DIR}/equinix-config.yaml.template" "${OUT_DIR}/equinix-config.yaml"
    fi
    if [ -n "${KAAS_AZURE_ENABLED}" ]; then
      cp "${TEMPLATES_DIR}/azure-config.yaml.template" "${OUT_DIR}/azure-config.yaml"
    fi
}

function template_machines {
    cp "${TEMPLATES_DIR}/machines.yaml.template" "${OUT_DIR}/machines.yaml"
    if [ -n "${KAAS_BM_ENABLED}" ]; then
      cp "${TEMPLATES_DIR}/baremetalhosts.yaml.template" "${OUT_DIR}/baremetalhosts.yaml"
    elif [ -f "${TEMPLATES_DIR}/rhellicenses.yaml.template" ]; then
      cp "${TEMPLATES_DIR}/rhellicenses.yaml.template" "${OUT_DIR}/rhellicenses.yaml"
    fi

}

function _kubectl_wait_till_exists {
    for _ in $(seq 1 60); do
        if _kubectl get "$@"; then
            return 0
        fi
        sleep 5
    done
    return 1
}

function _kubectl_wait_till_not_exists {
    for _ in $(seq 1 60); do
        if ! _kubectl get "$@"; then
            return 0
        fi
        sleep 5
    done
    return 1
}

function _kubectl_wait_for_job {
    _kubectl_wait_till_exists "$@"
    for _ in $(seq 1 30); do
        if _kubectl wait --for=condition=complete --timeout=30s "$@"; then
            return 0
        fi
    done
    return 1
}

function _kubectl_get_provider_type_from_cluster_object {
    local cluster=${1:-${CLUSTER_NAME}}
    local provider
    provider=$(_kubectl get cluster "${cluster}" -o=jsonpath='{.metadata.labels.kaas\.mirantis\.com/provider}')
    echo "${provider}"
}

function configure {
    mkdir -p "${OUT_DIR}"
    template_cluster
    template_machines
}

function bootstrap {
    log 'Starting management OpenStack cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --os-cloud "${OS_CLOUD}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --external-network "${NETWORK}" \
        --cluster-name "${CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --rhel-licenses "${OUT_DIR}/rhellicenses.yaml" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --region "region-one" \
        --custom-hostnames="${CUSTOM_HOSTNAMES}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log" \
        "$@"
}

function bootstrapv2 {
    log 'Starting bootstrap v2 cluster creation'

    # shellcheck disable=SC2046
    _kaas bootstrap create --v2 \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        "$@"
}

function bootstrap_aws {
    log 'Starting management AWS cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --rhel-licenses "${OUT_DIR}/rhellicenses.yaml" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --region "region-one" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log" \
        "$@"
}


function deploy_regional_os {
    log 'Starting regional OpenStack cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap regional create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --os-cloud "${OS_CLOUD}" \
        --external-network "${NETWORK}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --rhel-licenses "${OUT_DIR}/rhellicenses.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --credentials-name "${REGIONAL_CREDENTIALS_NAME}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function deploy_regional_aws {
    log 'Starting regional AWS cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap regional create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --rhel-licenses "${OUT_DIR}/rhellicenses.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --credentials-name "${REGIONAL_CREDENTIALS_NAME}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function deploy_regional_bm {
    log 'Starting regional BM cluster bootstrap process...'
    pre_bootstrap_kaas_bm
    # shellcheck disable=SC2046,SC2116
    _kaas bootstrap regional create \
        --use-existing-kind \
        --baremetalhosts "${OUT_DIR}/baremetalhosts.yaml" \
        --baremetalhostprofiles "${OUT_DIR}/baremetalhostprofiles.yaml" \
        --ipam-objects "${OUT_DIR}/ipam-objects.yaml" \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --dhcp-range "$KAAS_BM_BM_DHCP_RANGE" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        $( echo "${KAAS_CMDLINE_CEPHCLUSTER}") \
        "$@"
}

function deploy_regional_vsphere {
    log 'Starting regional vSphere cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap regional create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --vsphere-config-path "${OUT_DIR}/vsphere-config.yaml"  \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --rhel-licenses "${OUT_DIR}/rhellicenses.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --credentials-name "${REGIONAL_CREDENTIALS_NAME}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function deploy_regional_equinix {
    log 'Starting regional Equinix cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap regional create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --equinix-config-path "${OUT_DIR}/equinix-config.yaml"  \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --credentials-name "${REGIONAL_CREDENTIALS_NAME}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function deploy_regional_equinixmetalv2 {
    log 'Starting regional Equinix cluster bootstrap process...'
    pre_bootstrap_kaas_bm

    # shellcheck disable=SC2046
    _kaas bootstrap regional create \
        --use-existing-kind \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --equinix-config-path "${OUT_DIR}/equinix-config.yaml"  \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --credentials-name "${REGIONAL_CREDENTIALS_NAME}" \
        --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "${KAAS_CMDLINE_EQ2}" \
        "$@"
}


function deploy_regional_azure {
    log 'Starting regional Azure cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap regional create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --azure-config-path "${OUT_DIR}/azure-config.yaml"  \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-regional-cluster.log" \
        --mgmt-kubeconfig "${KUBECONFIG}" \
        --credentials-name "${REGIONAL_CREDENTIALS_NAME}" \
        --region "${REGION}" \
        --machine-prefix "${REGIONAL_CLUSTER_NAME}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function healthcheck {
    local kubeconfig=${1:-"kubeconfig"}
    log 'Waiting for cluster to become ready...'
    # shellcheck disable=SC2046
    _kaas cluster healthcheck \
        --cluster-kubeconfig "$kubeconfig" \
        --machines "${TEMPLATES_DIR}/machines.yaml.template"
}

function _collect_all_resources {
    local output_dir="${1}"
    local cluster_name="${2}"
    local cluster_namespace="${3}"
    local mgmtKubeconfig=${4}
    local kubeconfig=${5:-""}
    # mkeDebug is a flag to activate mke related additional debug features
    local mkeDebug="false"
    if [ -n "${KAAS_BOOTSTRAP_DEBUG}" ]; then
        mkeDebug="true"
    fi
    local extended="false"
    if [ -n "${COLLECT_EXTENDED_LOGS}" ]; then
        extended="true"
    fi
    log "[Logging directory: ${LOG_DIR}] Dumping all resources for ${cluster_name}..."
    if ! _kaas collect logs \
        --management-kubeconfig "${mgmtKubeconfig}" \
        --cluster-name "${cluster_name}" \
        --cluster-namespace "${cluster_namespace}" \
        --kubeconfig "${kubeconfig}" \
        --key-file "${SSH_PRIVATE_KEY_PATH}" \
        --output-dir "${output_dir}" \
        --mke-verbose=${mkeDebug} \
        --mke-service-driller=${mkeDebug} \
        --mke-audit=${mkeDebug} \
        --extended=${extended}; then
        logy "Couldn't dump resources from ${cluster_name}"
        return 1
    fi
}

function collect_logs {
    mkdir -p "${LOG_DIR}"
    local collected=false

    if [ -f "${CHILD_KUBECONFIG}" ] && [ -f "${KUBECONFIG}" ]; then
        if _collect_all_resources "${LOG_DIR}" "${CHILD_CLUSTER_NAME}" "${CHILD_CLUSTER_NAMESPACE}" "${KUBECONFIG}" "${CHILD_KUBECONFIG}"; then
            collected=true
        fi
    fi

    if [ -f "${REGIONAL_KUBECONFIG}" ] && [ -f "${KUBECONFIG}" ]; then
        if _collect_all_resources "${LOG_DIR}" "${REGIONAL_CLUSTER_NAME}" default "${KUBECONFIG}" "${REGIONAL_KUBECONFIG}"; then
            collected=true
        fi
    fi

    if [ -f "${KUBECONFIG}" ]; then
        if _collect_all_resources "${LOG_DIR}" "${CLUSTER_NAME}" default "${KUBECONFIG}"; then
            collected=true
        fi
    fi

    local kind_kubeconfig="${HOME}/.kube/kind-config-${BOOTSTRAP_CLUSTER_NAME}"
    if _kind get clusters -q | grep -q "${BOOTSTRAP_CLUSTER_NAME}"; then
        if [ -f "${KUBECONFIG}" ]; then
            # in this case we expect that we have been bootstrapping regional cluster, as management kubeconfig exists already
            if _collect_all_resources "${LOG_DIR}/bootstrap" "${REGIONAL_CLUSTER_NAME}" default "${KUBECONFIG}" "${kind_kubeconfig}"; then
                collected=true
            fi
        elif _collect_all_resources "${LOG_DIR}/bootstrap" "${CLUSTER_NAME}" default "${kind_kubeconfig}"; then
            collected=true
        fi
    fi

    if $collected; then
        log "Logs saved in: ${LOG_DIR}"
        find "${LOG_DIR}" -maxdepth 1
    else
        logy "No logs found"
    fi
}

function get_kaas_ui_ip {
    # shellcheck disable=SC2046
    service_ip="$(_kaas get kaas-ui-ip \
        --kubeconfig "${KUBECONFIG}")"
    echo "${service_ip}"
}

function get_urls {
    # shellcheck disable=SC2046
    resp="$(_kaas get management-endpoints \
        --kubeconfig "${KUBECONFIG}")"
    log "${resp}"
}

function deploy_child {
    # shellcheck disable=SC2046
    _kaas cluster create \
        --management-kubeconfig "${KUBECONFIG}" \
        --cluster-name "${CHILD_CLUSTER_NAME}" \
        --namespace "${CHILD_CLUSTER_NAMESPACE}" \
        --os-cloud "${OS_CLOUD}" \
        --credentials-name "${CLOUD_SECRET_NAME}" \
        --external-network "${NETWORK}" \
        --region "${REGION}" \
        --keyname "${SSH_KEY_NAME}" \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --release-name "${CHILD_K8S_RELEASE_NAME}" \
        --machine-prefix "${CHILD_MACHINE_PREFIX}" \
        --kubeconfig-output "${CHILD_KUBECONFIG}" \
        --realm "${KEYCLOAK_REALM}" \
        --username "${KAAS_USERNAME}" \
        --password "${KAAS_PASSWORD}" \
        --cluster "${TEMPLATES_DIR}/demo-child-cluster.yaml.template" \
        --machines "${TEMPLATES_DIR}/demo-child-machines.yaml.template" \
        --log-file "${LOG_DIR}/kaas-child-cluster.log"
}

function upgrade_child_release {
    # shellcheck disable=SC2046
    _kaas cluster upgrade \
        --management-kubeconfig "${KUBECONFIG}" \
        --cluster-kubeconfig "${CHILD_KUBECONFIG}" \
        --cluster-name "${CHILD_CLUSTER_NAME}" \
        --namespace "${CHILD_CLUSTER_NAMESPACE}" \
        --release-name "${CHILD_K8S_UPGRADE_RELEASE_NAME}"
}

function destroy_child {
    # shellcheck disable=SC2046
    _kaas cluster delete \
        --management-kubeconfig "${KUBECONFIG}" \
        --cluster-name "${CHILD_CLUSTER_NAME}" \
        --namespace "${CHILD_CLUSTER_NAMESPACE}" \
        --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
        --log-file "${LOG_DIR}/kaas-child-cluster-cleanup.log"

    rm -rf "${CHILD_KUBECONFIG}"
}

function destroy_cluster {
    local provider
    local use_existing_kind

    use_existing_kind="false"
    provider=$(_kubectl_get_provider_type_from_cluster_object ${CLUSTER_NAME})
    if [[ "${provider}" == "baremetal" ]]; then
        pre_bootstrap_kaas_bm
        use_existing_kind="true"
    fi

    # shellcheck disable=SC2046
    _kaas bootstrap delete \
        --use-existing-kind="${use_existing_kind}" \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --management-kubeconfig ${KUBECONFIG} \
        --dhcp-range "$KAAS_BM_BM_DHCP_RANGE" \
        --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
        --log-file "${LOG_DIR}/kaas-management-cluster-cleanup.log" \
        "$@"

    if [[ "${use_existing_kind}" == "true" ]]; then
        # shellcheck disable=SC2046
        _kaas bootstrap unprepare -v 10
    fi
}

function destroy_regional {
    local provider
    local use_existing_kind

    use_existing_kind="false"
    provider=$(_kubectl_get_provider_type_from_cluster_object ${REGIONAL_CLUSTER_NAME})
    if [[ "${provider}" == "baremetal" ]]; then
        pre_bootstrap_kaas_bm
        use_existing_kind="true"
    fi

    # shellcheck disable=SC2046
    _kaas bootstrap regional delete \
        --use-existing-kind="${use_existing_kind}" \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --cluster-name "${REGIONAL_CLUSTER_NAME}" \
        --management-kubeconfig ${KUBECONFIG} \
        --regional-kubeconfig ${REGIONAL_KUBECONFIG} \
        --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
        --log-file "${LOG_DIR}/kaas-regional-cluster-cleanup.log" \
        "$@"

    if [[ "${use_existing_kind}" == "true" ]]; then
        # shellcheck disable=SC2046
        _kaas bootstrap unprepare -v 10
    fi
}

function check_free_ip(){
    local _ip
    _ip="$1"
    if ping -c1 -w3 "${_ip}" >/dev/null 2>&1 ; then
        die "ERROR:KAAS-BM IP address: ${_ip} already allocated"
    fi
}

function pre_bootstrap_kaas_bm {
    log "KAAS-BM bootstrap kind"
    if docker inspect clusterapi-control-plane > /dev/null ; then
      logy 'KAAS-BM: Kind already bootstrapped'
      return
    fi

    # shellcheck disable=SC2046
    _kaas bootstrap prepare -v 10

    logy "KAAS-BM hack kind network"
    local CCP_PID
    CCP_PID="$(docker inspect clusterapi-control-plane --format='{{.State.Pid}}')"
    # opt
    sudo ip link del veth0-pxe || true
    check_free_ip "${KAAS_BM_PXE_IP}"
    sudo ip link add veth0-pxe type veth peer name veth0-docker
    sudo ip link set dev veth0-pxe up
    sudo brctl addif "${KAAS_BM_PXE_BRIDGE}" veth0-pxe
    sudo ip link set dev veth0-docker netns "${CCP_PID}"
    sudo nsenter -t "${CCP_PID}"  -n ip a
    sudo nsenter -t "${CCP_PID}"  -n ip link set dev veth0-docker up
    sudo nsenter -t "${CCP_PID}"  -n ip addr add "${KAAS_BM_PXE_IP}/${KAAS_BM_PXE_MASK}" dev veth0-docker
    sudo sysctl -w net.bridge.bridge-nf-call-arptables=0
    sudo sysctl -w net.bridge.bridge-nf-call-iptables=0
}

function fast_preflight_bootstrap_kaas_bm {
    log "KAAS-BM fast preflight starting..."
    # shellcheck disable=SC2046
    _kaas bootstrap preflight \
      --fast \
      --use-existing-kind \
      --provider baremetal \
      --baremetalhosts "${OUT_DIR}/baremetalhosts.yaml" \
      --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
      --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
      --cluster-name "${CLUSTER_NAME}" \
      --cluster "${OUT_DIR}/cluster.yaml" \
      --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
      --cdn-region "${KAAS_CDN_REGION}"
}

function bootstrap_kaas_bm {
    log 'Starting management BM cluster bootstrap process...'
    pre_bootstrap_kaas_bm
    # shellcheck disable=SC2046,SC2116
    _kaas bootstrap create \
      --use-existing-kind \
      --baremetalhosts "${OUT_DIR}/baremetalhosts.yaml" \
      --baremetalhostprofiles "${OUT_DIR}/baremetalhostprofiles.yaml" \
      --ipam-objects "${OUT_DIR}/ipam-objects.yaml" \
      --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
      --keyname "${SSH_KEY_NAME}" \
      --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
      --cluster-name "${CLUSTER_NAME}" \
      --cluster "${OUT_DIR}/cluster.yaml" \
      --machines "${OUT_DIR}/machines.yaml" \
      --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
      --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
      --cdn-region "${KAAS_CDN_REGION}" \
      --dhcp-range "$KAAS_BM_BM_DHCP_RANGE" \
      --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
      --region "region-one" \
      --custom-hostnames="${CUSTOM_HOSTNAMES}" \
      --internal-lb="${INTERNAL_LOAD_BALANCER}" \
      $( echo "${KAAS_CMDLINE_CEPHCLUSTER}") \
      --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log"
}

function bootstrap_vsphere {
    log 'Starting management vSphere cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --vsphere-config-path "${OUT_DIR}/vsphere-config.yaml"  \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --rhel-licenses "${OUT_DIR}/rhellicenses.yaml" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log" \
        --region "region-one" \
        --custom-hostnames="${CUSTOM_HOSTNAMES}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function bootstrap_equinix {
    log 'Starting management Equinix cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --equinix-config-path "${OUT_DIR}/equinix-config.yaml"  \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log" \
        --region "region-one" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function bootstrap_equinixmetalv2 {
    log 'Starting management Equinix cluster bootstrap process...'

    pre_bootstrap_kaas_bm

    # shellcheck disable=SC2046
    _kaas bootstrap create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --equinix-config-path "${OUT_DIR}/equinix-config.yaml"  \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log" \
        --region "region-one" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        --use-existing-kind \
        --metallb-pool "${BOOTSTRAP_METALLB_ADDRESS_POOL}" \
        "${KAAS_CMDLINE_EQ2}" \
        "$@"
}

function bootstrap_azure {
    log 'Starting management Azure cluster bootstrap process...'

    # shellcheck disable=SC2046
    _kaas bootstrap create \
        --bootstrap-cluster-name "${BOOTSTRAP_CLUSTER_NAME}" \
        --keyname "${SSH_KEY_NAME}" \
        --azure-config-path "${OUT_DIR}/azure-config.yaml"  \
        --private-key-path "${SSH_PRIVATE_KEY_PATH}" \
        --cluster-name "${CLUSTER_NAME}" \
        --cluster "${OUT_DIR}/cluster.yaml" \
        --machines "${OUT_DIR}/machines.yaml" \
        --cluster-release-dir "${CLUSTER_RELEASES_DIR}" \
        --kaas-release-yaml "${KAAS_RELEASE_YAML}" \
        --cdn-region "${KAAS_CDN_REGION}" \
        --log-file "${LOG_DIR}/kaas-bootstrap-cluster.log" \
        --region "region-one" \
        --custom-hostnames="${CUSTOM_HOSTNAMES}" \
        --internal-lb="${INTERNAL_LOAD_BALANCER}" \
        "$@"
}

function license_check {
  PROVIDER=openstack
  if [ -n "${KAAS_BM_ENABLED}" ]; then
    PROVIDER=baremetal
  elif [ -n "${KAAS_AWS_ENABLED}" ]; then
    PROVIDER=aws
  elif [ -n "${KAAS_VSPHERE_ENABLED}" ]; then
    PROVIDER=vsphere
  elif [ -n "${KAAS_EQUINIX_ENABLED}" ]; then
    PROVIDER=equinixmetal
  elif [ -n "${KAAS_EQUINIXMETALV2_ENABLED}" ]; then
    PROVIDER=equinixmetalv2
  elif [ -n "${KAAS_AZURE_ENABLED}" ]; then
    PROVIDER=azure
  fi

  # shellcheck disable=SC2046
  _kaas bootstrap license check --provider "$PROVIDER"
}

function version {
  log 'KaaS binary version'
  # shellcheck disable=SC2046
  _kaas version
}

function ensure_log_dir {
  mkdir -p "${LOG_DIR}"
}

function vsphere_template {
    log 'Vsphere VM template preparation'
    _kaas vsphere-template \
        --os-name "${VSPHERE_PACKER_IMAGE_OS_NAME}" \
        --os-version "${VSPHERE_PACKER_IMAGE_OS_VERSION}" \
        --rhel-licenses "${TEMPLATES_DIR}/rhellicenses.yaml.template" \
        --vsphere-config-path "${TEMPLATES_DIR}/vsphere-config.yaml.template" \
        --vsphere-cluster-config-path "${TEMPLATES_DIR}/cluster.yaml.template" \
        --vsphere-machines-path "${TEMPLATES_DIR}/machines.yaml.template" \
        --iso-file "${VSPHERE_PACKER_ISO_FILE}"
}

############################################################################
function usage() {
    echo "Usage: bootstrap.sh [ bootstrap | cleanup | configure | collect_logs | healthcheck | preflight ]"
    echo "Examples:"
    echo "  bootstrap.sh configure"
    echo "  bootstrap.sh preflight"
    echo "  bootstrap.sh bootstrap"
    echo "  bootstrap.sh healthcheck"
    echo "  bootstrap.sh cleanup"
    echo "  bootstrap.sh collect_logs"
}
############################################################################

function main {
    if [ "$#" -lt "1" ]; then
        echo "Too few arguments"
        usage
        exit 1
    fi

    version
    ensure_log_dir

    local arg
    arg="${1}"
    shift

    if [ "$arg" = "all" ]; then
        license_check
        if [ -n "${KAAS_BM_ENABLED}" ]; then
          configure
          bootstrap_kaas_bm "$@"
        elif [ -n "${KAAS_AWS_ENABLED}" ]; then
          configure
          bootstrap_aws "$@"
        elif [ -n "${KAAS_VSPHERE_ENABLED}" ]; then
          configure
          bootstrap_vsphere "$@"
        elif [ -n "${KAAS_EQUINIX_ENABLED}" ]; then
          configure
          bootstrap_equinix "$@"
        elif [ -n "${KAAS_EQUINIXMETALV2_ENABLED}" ]; then
          configure
          bootstrap_equinixmetalv2 "$@"
        elif [ -n "${KAAS_AZURE_ENABLED}" ]; then
          configure
          bootstrap_azure "$@"
        else
          configure
          log ' configure  <bootstrap>  get_urls '
          bootstrap "$@"
        fi
    elif [ "$arg" = "cleanup" ]; then
        if [ -f "${CHILD_KUBECONFIG}" ]; then
            destroy_child
        fi
        destroy_cluster "$@"
    elif [ "$arg" = "configure" ]; then
        configure
    elif [ "$arg" = "preflight" ]; then
        if [ -n "${KAAS_BM_ENABLED}" ]; then
            exit_code=0
            if [ -n "${KAAS_BM_FULL_PREFLIGHT}" ]; then
                logr "Full preflight is deprecated, exiting..." || (( exit_code+="$?" ))
            fi
            configure
            fast_preflight_bootstrap_kaas_bm || (( exit_code+="$?" ))
            exit "$exit_code"
        fi
    elif [ "$arg" = "bootstrap" ]; then
        bootstrap "$@"
    elif [ "$arg" = "bootstrapv2" ]; then
        bootstrapv2 "$@"
    elif [ "$arg" = "deploy_regional" ]; then
        license_check
        configure
        if [ -n "${KAAS_BM_ENABLED}" ]; then
          deploy_regional_bm "$@"
        elif [ -n "${KAAS_AWS_ENABLED}" ]; then
          deploy_regional_aws "$@"
        elif [ -n "${KAAS_VSPHERE_ENABLED}" ]; then
          deploy_regional_vsphere "$@"
        elif [ -n "${KAAS_EQUINIX_ENABLED}" ]; then
          deploy_regional_equinix "$@"
        elif [ -n "${KAAS_EQUINIXMETALV2_ENABLED}" ]; then
          deploy_regional_equinixmetalv2 "$@"
        elif [ -n "${KAAS_AZURE_ENABLED}" ]; then
          deploy_regional_azure "$@"
        else
          deploy_regional_os "$@"
        fi
    elif [ "$arg" = "healthcheck" ]; then
        healthcheck "${KUBECONFIG}"
    elif [ "$arg" = "get_urls" ]; then
        get_urls
    elif [ "$arg" = "get_kaas_ip" ]; then
        get_kaas_ui_ip
    elif [ "$arg" = "deploy_child" ]; then
        deploy_child
    elif [ "$arg" = "upgrade_child_release" ]; then
        upgrade_child_release
    elif [ "$arg" = "destroy_child" ]; then
        destroy_child
    elif [ "$arg" = "destroy_regional" ]; then
        destroy_regional "$@"
    elif [ "$arg" = "collect_logs" ]; then
        collect_logs
    elif [ "$arg" = "vsphere_template" ]; then
        vsphere_template
    elif [ "$arg" = "help" ] || [ "$arg" = "-h" ] ; then
        usage
    else
        "Wrong argument: $arg"
        usage
        exit 1
    fi
}

main "$@"
