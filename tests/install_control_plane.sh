#!/usr/bin/env bash
#

if [ -z ${1+x} ]; then
  echo "SHA not set, exiting..."
  exit 1
else
  ID=`echo ${1} | tail -c6`
  echo "Cluster ID: ${ID}"
fi

kubectl cluster-info
tctl version

