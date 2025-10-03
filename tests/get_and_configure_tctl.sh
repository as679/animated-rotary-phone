#!/usr/bin/env bash

set -e

TSB_ADDRESS=$1
TSB_ADMIN_PASSWORD=$2
VER=${3:-'1.13.0'}

sudo curl -Lo /usr/local/bin/tctl https://binaries.dl.tetrate.io/public/raw/versions/linux-amd64-${VER}/tctl
sudo chmod +x /usr/local/bin/tctl

tctl config clusters set default --bridge-address ${TSB_ADDRESS}
tctl config users set default --username admin --password ${TSB_ADMIN_PASSWORD} --org apidemo

tctl version