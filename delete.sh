#!/bin/bash

echo "=== delete.sh"

echo "--- removing known-hosts entries"

OHPC_IP4=$(tofu output -raw ohpc_ipv4)
if [[ -n "${OHPC_IP4}" ]] ; then
  ssh-keygen -R $OHPC_IP4
fi

OHPC_IP6=$(tofu output -raw ohpc_ipv6)
if [[ -n "${OHPC_IP6}" ]] ; then
  ssh-keygen -R $OHPC_IP6
fi

tofu destroy -auto-approve
