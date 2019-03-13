#!/bin/bash -xv

# Set a unique session name that is a valid DNS string
export GCP_SESSION_NAME=cnh-sess01

.  mk_gcp_gpu_vm_funcs.sh

echo $1

# Step 1
# create_local_container

# Step 2
# start_gcp_vm

# Step 3
# configure_gcp_vm 
