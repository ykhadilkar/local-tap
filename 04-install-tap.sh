#!/bin/bash
set -euo pipefail

# read the settings.sh file
readonly GIT_REPO_ROOT=$(git rev-parse --show-toplevel)
source ${GIT_REPO_ROOT}/config/settings.sh

#
# Apply overlay secrets
kubectl apply -f "${GIT_REPO_ROOT}/config/contour-overlay.yaml"

#
# Setup env vars that will be passed to ytt
#
export TAP_BASE_DOMAIN=${BASE_DOMAIN}
export TAP_INGRESS_DOMAIN=${TAP_BASE_DOMAIN}
export TAP_CATALOG_INFO="https://github.com/asaikali/tap-gui-sample-catalog/blob/main/catalog-info.yaml"
export TAP_GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
export TAP_GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
export TAP_WORKLOAD_REPO=${WORKLOAD_REGISTRY_REPO}
export TAP_SUPPLY_CHAIN=${SUPPLY_CHAIN}
export TAP_DEV_NAMESPACE=${DEV_NAMESPACE}

#
# Generate tap-values.yaml file
#
readonly VALUES_FILE_TEMPLATE=${GIT_REPO_ROOT}/config/tap-values-template.yaml
readonly VALUES_FILE="${GIT_REPO_ROOT}/workspace/generated/tap-values.yaml"
ytt -f ${VALUES_FILE_TEMPLATE} --data-values-env TAP > ${VALUES_FILE}

#
# Install tap 
#
tanzu package install tap \
    --package tap.tanzu.vmware.com \
    --version "${TAP_VERSION}" \
    --values-file "${VALUES_FILE}" \
    --namespace tap-install

#
# Generate Namespace config
#
readonly DEV_NS_FILE_TEMPLATE=${GIT_REPO_ROOT}/config/dev-ns-template.yaml
readonly DEV_NS_CONFIG_FILE="${GIT_REPO_ROOT}/workspace/generated/dev-ns.yaml"
ytt -f ${DEV_NS_FILE_TEMPLATE} --data-values-env TAP > ${DEV_NS_CONFIG_FILE}

kubectl apply -f ${DEV_NS_CONFIG_FILE}

#
# Generate tekton testing pipeline config
#
if [[ "$TAP_SUPPLY_CHAIN" == "testing" ]]; then
  readonly TEKTON_TESTING_FILE_TEMPLATE=${GIT_REPO_ROOT}/config/developer-defined-tekton-pipeline-template.yaml
  readonly TEKTON_TESTING_CONFIG_FILE="${GIT_REPO_ROOT}/workspace/generated/developer-defined-tekton-pipeline.yaml"
  ytt -f ${TEKTON_TESTING_FILE_TEMPLATE} --data-values-env TAP > ${TEKTON_TESTING_CONFIG_FILE}

  kubectl apply -f ${TEKTON_TESTING_CONFIG_FILE}
fi