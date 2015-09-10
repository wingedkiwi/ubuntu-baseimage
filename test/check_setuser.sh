#!/bin/bash

if [[ "$(whoami)" == "www-data" ]]; then
    echo check_setuser.sh: success
else
    echo check_setuser.sh: failed: Expected script ran as www-data but was $(whoami)
    exit 1
fi

