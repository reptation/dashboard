#!/bin/bash
set -x

# Creates a temporary var file for terraform. Represents a compromise between trying to set a lot of TF_VAR_foobar env var's and hard-coding stuff. 

# TODO create a policy where terraform apply can only run in regions not us-east-1

# TODO switch statement with --yes|y to run terraform apply subject to policy restriction(s)

TMP_VARS=tmp.vars.tfvars

cd $(dirname "$0"); cd ../terraform

config_env_file () {
    envsubst < terraform.tfvars.env > "${TMP_VARS}" ; 
    echo "vars configured for branch $GIT_BRANCH, $AWS_DEFAULT_REGION"
    cat "${TMP_VARS}"
}

run_terraform_with_config () {
    terraform plan -var-file="${TMP_VARS}"
#    terraform apply -var-file="${TMP_VARS}"
}

cleanup_tmp_vars () {
    echo "Removing temporary vars file"
    rm "${TMP_VARS}"
}

config_env_file
run_terraform_with_config
cleanup_tmp_vars
