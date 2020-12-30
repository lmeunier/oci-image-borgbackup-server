#!/usr/bin/env bash

set -e

if ls /etc/ssh/host_keys/ssh_host_* 1> /dev/null 2>&1; then
    echo ">> Found Host keys in default location"
else
    echo ">> Generating new host keys"
    ssh-keygen -A
    mv /etc/ssh/ssh_host_*  /etc/ssh/host_keys/
fi

echo ">> Running $@"
exec "$@"

