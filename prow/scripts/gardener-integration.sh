#!/usr/bin/env bash

# This script is designed to provision a new vm and start kyma with cli. It takes an optional positional parameter using --image flag
# Use this flag to specify the custom image for provisioning vms. If no flag is provided, the latest custom image is used.

set -o errexit

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly TEST_INFRA_SOURCES_DIR="$(cd "${SCRIPT_DIR}/../../" && pwd)"
KYMA_PROJECT_DIR=${KYMA_PROJECT_DIR:-"/home/prow/go/src/github.com/kyma-project"}

#Exported variables
export TEST_INFRA_SOURCES_DIR="${KYMA_PROJECT_DIR}/test-infra"
export TEST_INFRA_CLUSTER_INTEGRATION_SCRIPTS="${TEST_INFRA_SOURCES_DIR}/prow/scripts/cluster-integration/helpers"
# shellcheck disable=SC1090
source "${TEST_INFRA_SOURCES_DIR}/prow/scripts/library.sh"
# shellcheck disable=SC1090
source "${TEST_INFRA_SOURCES_DIR}/prow/scripts/lib/testing-helpers.sh"

#TODO
#kubectl kms i bucket
#Kind image eu.gcr.io/kyma-project/test-infra/buildpack-golang-toolbox:v20191011-51ed45a
#job config z joba integracyjnego, odpalany na PR
#
#co z deprovisioningiem?

readonly TMP_DIR=$(mktemp -d)
readonly SUITE_NAME="testsuite-all"


os() {
  local host_os
  case "$(uname -s)" in
    Darwin)
      host_os=darwin
      ;;
    Linux)
      host_os=linux
      ;;
    *)
      error "Unsupported host OS. Must be Linux or Mac OS X."
      exit 1
      ;;
  esac
  echo "${host_os}"
}

kyma_cli() {
    mkdir -p "${INSTALL_DIR}/bin"
    export PATH="${INSTALL_DIR}/bin:${PATH}"
    os=$(host::os)

    pushd "${INSTALL_DIR}/bin"


    echo -e "- Install kyma CLI ${os} locally to a tempdir..."

    curl -sSLo kyma "https://storage.googleapis.com/kyma-cli-develop-version/kyma-${os}?alt=media"
    chmod +x kyma

    echo -e "OK"

    popd
}

shout "Provisioning Gardener"
date
sudo kyma provision gardener -c "${GARDENER_KYMA_PROW_KUBECONFIG}" -n kyma-gardener-cli -p kyma-prow -s neighbors-gardener-gcp
echo -e "LS: `ls`, PWD: `pwd`"
shout "Installing Kyma"
date
#sudo kyma install --non-interactive

shout "Checking the versions"
date
#sudo kyma version

shout "Running tests on Kyma"
date
#kyma test run \
                --name "${SUITE_NAME}" \
                --concurrency "${CONCURRENCY}" \
                --max-retries 1 \
                --timeout "1h" \
                --watch \
                --non-interactive

echo "Check if the test succeeds"
date
attempts=3
for ((i=1; i<=attempts; i++)); do
    result=$(sudo kyma test status -o json" | jq '.status.results[0].status')
    if [[ "$result" == *"Succeeded"* ]]; then
        echo "The test succeeded"
        break
    elif [[ "${i}" == "${attempts}" ]]; then
        echo "ERROR: test result is ${result}"
        exit 1
    fi
    echo "Sleep for 15 seconds"
    sleep 15
done

shout "Uninstalling Kyma"
date
gcloud compute ssh --quiet --zone="${ZONE}" "cli-integration-test-${RANDOM_ID}" -- "sudo kyma uninstall --non-interactive"


