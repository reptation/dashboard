#!/bin/bash

cd $(dirname "$0")
. ./get-creds.sh
cd ../

# Do not change this value without adjusting packer and terraform
# Note: currently modifying packer to use this same variable
export AMI_NAME="dashboard-ami-${GIT_BRANCH}"


echo "De-registering AMI with name ${AMI_NAME}, if one exists"
sleep 3
AMI_ID=$(aws ec2 describe-images --filters "Name=name,Values=${AMI_NAME}" | grep "ImageId" | sed 's/"ImageId": "//g' | sed 's/",//g' | tr -d ' ' ) 
echo "${AMI_NAME} id is ${AMI_ID}"
aws ec2 deregister-image --image-id "${AMI_ID}"
if [ "$?" == "0" ]; then
  echo "Image deregistered"
else
  echo "Image not deregistered"
fi

pushd packer
packer build webworker-dashboard.json
popd 


