#!/bin/sh
# This should be sourced ('source'/'.'), not executed

export AWS_ACCESS_KEY_ID=$(pass aws/aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(pass aws/aws_secret_access_key)
export AWS_DEFAULT_REGION=$(pass aws/aws_default_region)
export AWS_DB_PASS=$(pass aws/vpc/aws_db_pass)
export DOCKERHUB_USER=$(pass dockerhub/dockerhub_user)
export DOCKERHUB_PASS=$(pass dockerhub/dockerhub_pass)

