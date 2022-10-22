#!/bin/bash
container_birth_timestamp=$(expr $(date +%s -r /opt/SecureSpan/Gateway/node/default/var/started) - $(date +%s -r /opt/SecureSpan/Gateway/node/default/var/preboot))
if [ "$container_birth_timestamp" -ge 0 ]; then
    exit 0
fi