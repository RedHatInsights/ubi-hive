#!/bin/bash

echo "os: $OSTYPE"
echo "shell: $SHELL"
export PATH=$PATH:$PWD

# --------------------------------------------
# Options that must be configured by app owner
# --------------------------------------------
APP_NAME="hccm"  # name of app-sre "application" folder this component lives in
COMPONENT_NAME="hive-metastore"  # name of app-sre "resourceTemplate" in deploy.yaml for this component
IMAGE_REPO="quay.io"
ORG="cloudservices"
APP="ubi-hive"
IMAGE="${IMAGE_REPO}/${ORG}/${APP}"


echo "LABEL quay.expires-after=3d" >> ./Dockerfile # tag expire in 3 days

# Install bonfire repo/initialize
CICD_URL=https://raw.githubusercontent.com/RedHatInsights/bonfire/master/cicd
curl -s $CICD_URL/bootstrap.sh > .cicd_bootstrap.sh && source .cicd_bootstrap.sh

source $CICD_ROOT/build.sh
#source $CICD_ROOT/deploy_ephemeral_env.sh
#source $CICD_ROOT/smoke_test.sh

source $CICD_ROOT/_common_deploy_logic.sh
export NAMESPACE=$(bonfire namespace reserve)
oc process --local -f deploy/clowdapp.yaml | oc apply -f - -n $NAMESPACE

mkdir -p $WORKSPACE/artifacts
cat << EOF > ${WORKSPACE}/artifacts/junit-dummy.xml
<testsuite tests="1">
    <testcase classname="dummy" name="dummytest"/>
</testsuite>
EOF
