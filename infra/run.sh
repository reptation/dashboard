#!/bin/bash
set -e
# Assumes packer and terraform are installed

# start from infra directory
cd $(dirname "$0")
if [ -z "${GIT_BRANCH}" ];then
    source ./scripts/get-creds.sh
    if [ -z "${GIT_BRANCH}" ];then
        echo "Failed to get branchname. Exiting"
        exit 1
    fi
fi

./scripts/replace-packer-ami.sh
#pushd ./packer
#packer build webworker-dashboard.json
#popd 

./scripts/config-and-run-terraform.sh
#pushd ./terraform
#terraform init
#terraform apply
#popd

echo "Deployment Complete"

