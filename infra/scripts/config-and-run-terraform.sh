#!/bin/bash
#set -x

# create separate directories for each branch so each has a separate state file. ref: https://charity.wtf/2016/03/30/terraform-vpc-and-why-you-want-a-tfstate-file-per-env/

cd $(dirname "$0"); 
if [ -z "${GIT_BRANCH}" ];then
    source ./get-creds.sh
#    echo GIT_BRANCH env var must be set. Exiting.
#    exit 1
fi

cd ../terraform

# TODO switch statement with --yes|y to run terraform apply subject to policy restriction(s)

TMP_VARS_FILE=tmp.vars.tfvars
TMP_VARS_FILE_TEMPLATE="${TMP_VARS_FILE}".env

use_branch_dir () {
    if [ ! -d "./${GIT_BRANCH}" ]; then
      NEW_BRANCH=true
      echo "Creating new directory for environment ${GIT_BRANCH}"
      mkdir "${GIT_BRANCH}"
      # get started with template from prod
      cp prod/prod.tf "${GIT_BRANCH}"/"${GIT_BRANCH}".tf; cp prod/"${TMP_VARS_FILE_TEMPLATE}" "${GIT_BRANCH}"/
    fi

    cd "${GIT_BRANCH}"
}

config_env_file () {
    envsubst < "${TMP_VARS_FILE_TEMPLATE}" > "${TMP_VARS_FILE}" ; 
    echo "vars configured for branch $GIT_BRANCH, $AWS_DEFAULT_REGION"
    cat "${TMP_VARS_FILE}"
}

run_terraform_with_config () {
    if [ "${NEW_BRANCH}" == "true" ];then
        terraform init
    fi
    
    terraform plan -var-file="${TMP_VARS_FILE}"
    
    if [ "${AWS_DEFAULT_REGION}" == "us-east-1" ];then
        echo "Sorry, us-east-1 is production, and does not currently go through this script"
        exit 0
    fi 

    echo "Do you want to run terraform apply? (y/n)"
    read response
    case "${response}" in
        yes|y|Y) 
            echo "Proceeding"
            terraform apply -var-file="${TMP_VARS_FILE}"
        ;;
        *) echo "Did not get y"
        ;;
    esac
}

cleanup_tmp_vars () {
    echo "Removing temporary vars file"
    rm "${TMP_VARS_FILE}"
}

use_branch_dir
config_env_file
run_terraform_with_config

# leave the vars file
cleanup_tmp_vars

