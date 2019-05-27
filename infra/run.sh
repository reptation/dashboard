#!/bin/bash

# Assumes packer and terraform are installed

# start from infra directory
cd $(dirname "$0")

pushd ./packer
packer build webworker-dashboard.json
popd 

pushd ./terraform
terraform init
terraform apply
popd

echo "Deployment Complete"

