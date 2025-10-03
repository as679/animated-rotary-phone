#!/usr/bin/env bash

set -e

TSB_ADDRESS=$1
TSB_ADMIN_PASSWORD=$2
VER=${3:-'1.13.0'}

sudo ./get_tctl.sh -v ${VER}

tctl config clusters set default --bridge-address ${TSB_ADDRESS}
tctl config users set default --username admin --password ${TSB_ADMIN_PASSWORD} --org apidemo

tctl version