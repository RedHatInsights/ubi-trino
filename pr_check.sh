#!/bin/bash

echo "os: $OSTYPE"
echo "shell: $SHELL"
export PATH=$PATH:$PWD
set -ex
# --------------------------------------------
# Options that must be configured by app owner
# --------------------------------------------
APP_NAME="hccm"  # name of app-sre "application" folder this component lives in
COMPONENT_NAME="trino"  # name of app-sre "resourceTemplate" in deploy.yaml for this component
IMAGE_REPO="quay.io"
ORG="cloudservices"
APP="ubi-trino"
IMAGE="${IMAGE_REPO}/${ORG}/${APP}"
EXTRA_DEPLOY_ARGS="--set-parameter trino/IMAGE=${IMAGE}"
COMPONENTS="hive-metastore koku trino"  # specific components to deploy (optional, default: all)
COMPONENTS_W_RESOURCES="hive-metastore koku trino"  # components which should preserve resource settings (optional, default: none)

# Install bonfire repo/initialize
CICD_URL=https://raw.githubusercontent.com/RedHatInsights/bonfire/master/cicd
curl -s $CICD_URL/bootstrap.sh > .cicd_bootstrap.sh && source .cicd_bootstrap.sh

source $CICD_ROOT/build.sh

# source $CICD_ROOT/_common_deploy_logic.sh
# export NAMESPACE=$(bonfire namespace reserve)
# oc process --local -f deploy/clowdapp.yaml | oc apply -f - -n $NAMESPACE
source $CICD_ROOT/deploy_ephemeral_env.sh
#source $CICD_ROOT/smoke_test.sh

mkdir -p $WORKSPACE/artifacts
cat << EOF > ${WORKSPACE}/artifacts/junit-dummy.xml
<testsuite tests="1">
    <testcase classname="dummy" name="dummytest"/>
</testsuite>
EOF
