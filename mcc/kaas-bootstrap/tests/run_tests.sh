#!/usr/bin/env bash


CNF_NAMESPACE="${CNF_NAMESPACE:-conformance}"
SL_NAMESPACE="${SL_NAMESPACE:-stacklight}"
SL_TESTS_NAMESPACE="${SL_TESTS_NAMESPACE:-sl-tests}"
BASEDIR=$(dirname "$0")
# Locate test template:
CNF_TEMPL="$BASEDIR/test-templates/conformance.yml.tmpl"
SL_SA_TEMPL="$BASEDIR/test-templates/sl-sa.yml.tmpl"
SL_POD_TEMPL="$BASEDIR/test-templates/sl-pod.yml.tmpl"
PVC_TEMPL="$BASEDIR/test-templates/results-pvc.yml.tmpl"
GATH_TEMPL="$BASEDIR/test-templates/gatherer.yml.tmpl"

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

function verify_exec {
    if ! [[ "$TEST_SUITE" =~ ^(conformance|stacklight)$ ]];
    then
        logr "Test suite parameter has incorrect value. The correct ones are 'conformance' or 'stacklight'";
        helpFunction
        exit 1
    fi
    if [[ -z "$MGMT" ]]
    then
        logr "Management config is unfilled";
        helpFunction
        exit 1
    fi
    if [[ -z "$CHILD" ]]
    then
        logr "Child config is unfilled";
        helpFunction
        exit 1
    fi
    if [[ ! $(command -v kubectl) ]]
    then
        logy "No kubectl installation found. Downloading upstream kubectl for you."
        curl -L https://storage.googleapis.com/kubernetes-release/release/"$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
        chmod a+x /usr/local/bin/kubectl
    fi
}

function helpFunction {
   echo ""
   echo "Usage: $0 -t=test-suite -m=management.yml -c=child.yml (run gen grab status cleanup full_cleanup)"
   echo -e "\t-t|--test-suite Test suite to launch (conformance stacklight) (mandatory)"
   echo -e "\t-m|--management Kubeconfig of management cluster (mandatory)"
   echo -e "\t-c|--child      Kubeconfig of child cluster (mandatory)"
   echo -e "\t-i|--image      Use custom image for run instead of autodetected."
   echo -e "\t run            Execute tests for provided child cluster"
   echo -e "\t gen            Generate definition for required objects for further usage"
   echo -e "\t grab           Get results and logs of test run"
   echo -e "\t status         Get status of pod with tests"
   echo -e "\t cleanup        Remove pod from cluster"
   echo -e "\t full_cleanup   Remove all generated stuff and all test stuff from cluster"
   exit 1 # Exit script after printing help
}

function discover {
    # Generate names for resources:
    COMMON_NAME=$(kubectl --kubeconfig "${CHILD}" config get-clusters | tail -n+2)
    WORKDIR=${BASEDIR}/${COMMON_NAME}
    SL_SA_LOC=${WORKDIR}/sl-sa-${COMMON_NAME}.yml
    PVC_DEF_LOC=${WORKDIR}/results-pvc-${COMMON_NAME}.yml
    GATH_DEF_LOC=${WORKDIR}/gatherer-${COMMON_NAME}.yml
    CUSTOM_IMAGE="${CUSTOM_IMAGE:-}"
    POD_REPORT_DIR="${POD_REPORT_DIR:-/report}"
    case "${TEST_SUITE}" in
        "conformance")
        NAMESPACE="${CNF_NAMESPACE}"
        POD_DEFINITION=${WORKDIR}/conformance-${COMMON_NAME}.yml
        K8S_VERSION=$(kubectl --kubeconfig "${CHILD}" version --short | grep Server | awk -F' ' '{print $3}' | sed -e 's/+.*//g')
        log "Child cluster version: ${K8S_VERSION}"
        IMAGE_LINK=${CUSTOM_IMAGE:="docker-dev-kaas-local-eu.mcp.mirantis.net/lcm/kubernetes/k8s-conformance:$K8S_VERSION"}
        ;;
        "stacklight")
        NAMESPACE="${SL_TESTS_NAMESPACE}"
        POD_DEFINITION=${WORKDIR}/sl-pod-${COMMON_NAME}.yml
        IMAGE_LINK="${CUSTOM_IMAGE:="docker-dev-kaas-local-eu.mcp.mirantis.net/stacklight/stacklight-pytest:nightly"}"
    esac
}

function generate_gatherer {
    mkdir "${WORKDIR}"
    sed "s|COMMON_NAME|$COMMON_NAME|g" "${PVC_TEMPL}" > "${PVC_DEF_LOC}"
    sed "s|COMMON_NAME|$COMMON_NAME|g" "${GATH_TEMPL}" > "${GATH_DEF_LOC}"
    sed -i "s|TEST_NAMESPACE|$NAMESPACE|g" "${PVC_DEF_LOC}"
    sed -i "s|TEST_NAMESPACE|$NAMESPACE|g" "${GATH_DEF_LOC}"
    sed -i "s|IMAGE|$IMAGE_LINK|g" "${GATH_DEF_LOC}"
    sed -i "s|POD_REPORT_DIR|$POD_REPORT_DIR|g" "${GATH_DEF_LOC}"
    log "Definitions for $TEST_SUITE gatherer resources built: $PVC_DEF_LOC, $GATH_DEF_LOC"
}

function generate_conformance {
    log "Child cluster name from kubeconfig: $COMMON_NAME"
    sed "s|COMMON_NAME|$COMMON_NAME|g" "${CNF_TEMPL}" > "${POD_DEFINITION}"
    sed -i "s|CNF_NAMESPACE|$NAMESPACE|g" "${POD_DEFINITION}"
    sed -i "s|CNF_IMAGE|$IMAGE_LINK|g" "${POD_DEFINITION}"
    sed -i "s|POD_REPORT_DIR|$POD_REPORT_DIR|g" "${POD_DEFINITION}"
    CHILD_CONF_FILENAME=${CHILD##*/}
    sed -i "s|CHILD_CONF_FILENAME|$CHILD_CONF_FILENAME|g" "${POD_DEFINITION}"
    log "Conformance definitions built: $POD_DEFINITION"
}

function generate_stacklight {
    log "Cluster name from kubeconfig: $COMMON_NAME"
    if [[ -f ${SL_SA_LOC} ]]
    then
        logy "Service account definitions for cluster $COMMON_NAME exists and will be rewritten."
        kubectl --kubeconfig "${CHILD}" delete -f "${SL_SA_LOC} " --ignore-not-found
        rm -f "${SL_SA_LOC}"
    fi
    # Create a service account with admin privileges in the child cluster
    sed "s|COMMON_NAME|$COMMON_NAME|g" "${SL_SA_TEMPL}" > "${SL_SA_LOC}"
    sed -i "s|SL_NAMESPACE_VALUE|$SL_NAMESPACE|g" "${SL_SA_LOC}"
    log "Service account for stacklight tests in the child cluster built: $SL_SA_LOC"
    kubectl --kubeconfig "${CHILD}" create -f "${SL_SA_LOC}"
    # Create a pod definition to run tests in the mgmt cluster
    sed "s|COMMON_NAME|$COMMON_NAME|g" "${SL_POD_TEMPL}" > "${POD_DEFINITION}"
    sed -i "s|TEST_NAMESPACE|$NAMESPACE|g" "${POD_DEFINITION}"
    CONF_FILENAME=${CHILD##*/}
    sed -i "s|CONF_FILENAME|$CONF_FILENAME|g" "${POD_DEFINITION}"
    sed -i "s|SL_NAMESPACE_VALUE|$SL_NAMESPACE|g" "${POD_DEFINITION}"
    sed -i "s|POD_REPORT_DIR|$POD_REPORT_DIR|g" "${POD_DEFINITION}"
    URL=$(kubectl --kubeconfig "${CHILD}" config view --minify | grep server | cut -f 2- -d ":" | tr -d " ")
    sed -i "s|URL_VALUE|$URL|g" "${POD_DEFINITION}"
    SECRETNAME=$(kubectl --kubeconfig "${CHILD}" get secrets -n "${SL_NAMESPACE}" | grep "${COMMON_NAME}" | awk '{print $1}')
    TOKEN=$(kubectl --kubeconfig "${CHILD}" describe secret "${SECRETNAME}" -n "${SL_NAMESPACE}" | grep -E '^token' | cut -f2 -d':' | tr -d " ")
    sed -i "s|TOKEN_VALUE|$TOKEN|g" "${POD_DEFINITION}"
    sed -i "s|IMAGE|$IMAGE_LINK|g" "${POD_DEFINITION}"
    KEYCLOAK_URL=$(kubectl --kubeconfig "${MGMT}" get services -o=jsonpath='{.items[?(@.metadata.name == "iam-keycloak-http")].spec.loadBalancerIP}' -n kaas)
    sed -i "s|KEYCLOAK_VALUE|https://$KEYCLOAK_URL|g" "${POD_DEFINITION}"
    log "Pod definition built: $POD_DEFINITION"
}

function execute {
    generate_gatherer
    if [[ -f ${POD_DEFINITION} ]]
    then
        logy "Conformance definitions for cluster $COMMON_NAME exists and will be rewritten."
        rm -f "${POD_DEFINITION}"
    fi
    if [[ ! $(kubectl --kubeconfig "${MGMT}" get ns "${NAMESPACE}" 2>/dev/null) ]]
    then
        logy "No namespace for $TEST_SUITE tests found. Creating namespace with name '$NAMESPACE'"
        kubectl --kubeconfig "${MGMT}" create ns "${NAMESPACE}"
    else
        if [[ $(kubectl --kubeconfig "${MGMT}" get po "${COMMON_NAME}" -n "${NAMESPACE}" 2>/dev/null) ]]
        then
            die "Active $TEST_SUITE tests run for cluster $COMMON_NAME detected. No additional pod will be created."
        fi
        if [[ $(kubectl --kubeconfig "${MGMT}" get po gatherer-"${COMMON_NAME}" -n "${NAMESPACE}" 2>/dev/null) ]]
        then
            logy "Gatherer pod detected for cluster ${COMMON_NAME}. Removing it to reset PVC mount."
            kubectl --kubeconfig "${MGMT}" delete -f "${GATH_DEF_LOC}" 2>/dev/null
        fi
    fi
    if [[ ! $(kubectl --kubeconfig "${MGMT}" get secret -n "${NAMESPACE}" kubeconfig 2>/dev/null) ]]
    then
        logy "No child config found in secret. Creating config secret for cluster '$COMMON_NAME'"
        kubectl --kubeconfig "${MGMT}" create secret generic -n "${NAMESPACE}" kubeconfig --from-file="${CHILD}"
    fi
    if [[ ! -f ${POD_DEFINITION} ]]
    then
        logy "No definitions found for provided child cluster configuration. Need to create one..."
        generate_"${TEST_SUITE}"
    fi
    kubectl --kubeconfig "${MGMT}" replace -f "${PVC_DEF_LOC}" --force
    kubectl --kubeconfig "${MGMT}" create -f "${POD_DEFINITION}"
    log "Enjoy!"
}

function cleanup {
    kubectl --kubeconfig "${MGMT}" delete -f "${POD_DEFINITION}" -f "${GATH_DEF_LOC}" -f "${PVC_DEF_LOC}"
    if [[ -f ${SL_SA_LOC} ]]
    then
        kubectl --kubeconfig "${CHILD}" delete -f "${SL_SA_LOC}"
        rm -f "${SL_SA_LOC}"
    fi
}

function full_cleanup {
    cleanup
    kubectl --kubeconfig "${MGMT}" delete ns "${NAMESPACE}"
    rm -f "${POD_DEFINITION}"
    rm -f "${GATH_DEF_LOC}"
    rm -f "${PVC_DEF_LOC}"
}

function pod_status {
    pod_name="$1"
    status=$(kubectl --kubeconfig "${MGMT}" get po "${pod_name}" -n "${NAMESPACE}" 2>/dev/null | awk '{print $3}' | tail -n+2)
    if [[ -z "${status}" ]]
    then
        die "No active runs found"
    fi
    echo "${status}"
}

function grab {
    if [[ ! $(kubectl --kubeconfig "${MGMT}" get po gatherer-"${COMMON_NAME}" -n "${NAMESPACE}" 2>/dev/null) ]]
    then
        test_pod_status=$(pod_status "${COMMON_NAME}")
        if [[ ! ${test_pod_status} =~ ^(Completed|Error)$ ]]
        then
            die "Test pod in ${test_pod_status} state. Result gathering unavailable. Please wait for test run completion."
        fi
        logy "Removing test pod to re-mount results volume to gatherer"
        kubectl --kubeconfig "${MGMT}" delete -f "${POD_DEFINITION}"
        logy "No gatherer pod found. Spawning it."
        kubectl --kubeconfig "${MGMT}" create -f "${GATH_DEF_LOC}"
    fi
    while [[ $(pod_status gatherer-"${COMMON_NAME}") != "Running" ]]
    do
        log "Gatherer pod is not ready to copy results. Status: $(pod_status gatherer-"${COMMON_NAME}")"
        sleep 5
        if [[ $(pod_status gatherer-"${COMMON_NAME}") =~ ^(Error|CrashLoopBackOff|ImgErrPull)$ ]]
        then
            die "Smth wrong with gatherer pod. Please check."
        fi
    done
    REPORT_DIR=${WORKDIR}/results
    mkdir "${REPORT_DIR}"
    kubectl --kubeconfig "${MGMT}" cp "${NAMESPACE}"/gatherer-"${COMMON_NAME}":"${POD_REPORT_DIR}"/ "${REPORT_DIR}"/
    log "Results copied and located in $REPORT_DIR."
}

function main () {
    if [[ "$#" -lt "1" ]]; then
        logr "Too few arguments"
        helpFunction
        exit 1
    fi

    for i in "$@"
    do
    case ${i} in
        -t=*|--test-suite=*)
        TEST_SUITE="${i#*=}"
        log "Test suite set to: $TEST_SUITE"
        shift # past argument=value
        ;;
        -m=*|--management=*)
        MGMT="${i#*=}"
        log "Management cluster kubeconfig location set to: $MGMT"
        shift # past argument=value
        ;;
        -c=*|--child=*)
        CHILD="${i#*=}"
        log "Child cluster kubeconfig location set to: $CHILD"
        shift # past argument=value
        ;;
        -i=*|--image=*)
        CUSTOM_IMAGE="${i#*=}"
        log "Image set to $CUSTOM_IMAGE"
        shift
        ;;
        run)
        verify_exec
        discover
        log "Running $TEST_SUITE tests for cluster $COMMON_NAME"
        execute
        ;;
        gen)
        verify_exec
        discover
        log "Generated definition for $TEST_SUITE tests for cluster $COMMON_NAME"
        generate_gatherer
        generate_"${TEST_SUITE}"
        ;;
        status)
        verify_exec
        discover
        log "Gathering status for $TEST_SUITE tests for cluster $COMMON_NAME"
        pod_status "${COMMON_NAME}"
        log "$TEST_SUITE tests pod status in $status state"
        ;;
        grab)
        verify_exec
        discover
        log "Gathering results for $TEST_SUITE tests for cluster $COMMON_NAME"
        grab
        ;;
        cleanup)
        verify_exec
        discover
        log "Removing pod for cluster $COMMON_NAME"
        cleanup
        logy "Namespace $NAMESPACE and config for cluster $COMMON_NAME will not be removed"
        ;;
        full_cleanup)
        verify_exec
        discover
        log "Performing full cleanup"
        full_cleanup
        logy "Namespace $NAMESPACE and config for cluster $COMMON_NAME will be removed"
        ;;
        *)
        helpFunction      # unknown option
        ;;
    esac
    done
}

main "$@"
