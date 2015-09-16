#!/bin/bash
set -euo pipefail

NAME=${NAME:-"wingedkiwi/baseimage"}
VERSION=${VERSION:-"latest"}

EXPECTED_SCRIPT_ORDER="00-first.sh 10-second.sh 15-last.sh rc.local"
EXPECTED_START_ORDER="10-syslog-forwarder 10-syslog-ng 20-cron"
EXPECTED_STOP_ORDER="20-cron 10-syslog-ng 10-syslog-forwarder"

echo "Run ${NAME}:${VERSION} image"
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

set +e
output=$(docker run \
           -v "${DIR}":/test \
           -v "${DIR}/disabled_service":/etc/service/30-disabled_service \
           -v "${DIR}/my_init.d":/etc/my_init.d \
           -v "${DIR}/rc.local":/etc/rc.local \
           --rm -t ${NAME}:${VERSION} /test/check_services.sh)
set -e

echo -e "${output}"

echo "Remove files created by runit"
sudo rm -rf "${DIR}/disabled_service/supervise" "${DIR}/disabled_service/down"

echo "Check if boot scripts were started"
script_list=$(echo -e "${output}" | grep "script-test:" | awk  -F" " '{ print $2 }')
if [[ "$(echo ${script_list})" != "${EXPECTED_SCRIPT_ORDER}" ]]; then
    echo -e expected boot script execution order to be \"${EXPECTED_SCRIPT_ORDER}\" but was \"${script_list}\"
    exit 1
fi

echo "Check service start order"
start_list=$(echo -e "${output}" | grep "*** Start" | awk  -F" " '{ print $3 }' | rev | cut -c 5- | rev)
stop_list=$(echo -e "${output}" | grep "*** Stop" | awk  -F" " '{ print $3 }' | rev | cut -c 5- | rev)

if [[ "$(echo ${start_list})" != "${EXPECTED_START_ORDER}" ]]; then
    echo -e expected start order to be \"${EXPECTED_START_ORDER}\" but was \"${start_list}\"
    exit 1
fi

echo "Check service stop order"
if [[ "$(echo ${stop_list})" != "${EXPECTED_STOP_ORDER}" ]]; then
    echo -e expected stop order to be \"${EXPECTED_STOP_ORDER}\" but was \"${stop_list}\"
    exit 1
fi

echo "Check if check_services.sh was executed successfully"
echo -e "${output}" | grep "check_services.sh: success" > /dev/null

echo "Test setuser"
docker run -v "${DIR}":/test --rm -it ${NAME}:${VERSION} setuser www-data /test/check_setuser.sh
