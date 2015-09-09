#!/bin/bash
set -euo pipefail

# Check if system services are up
for service in "10-syslog-ng 10-syslog-forwarder 20-cron"
do
    /usr/bin/sv status /etc/service/${service} | grep run:
done

# Check if dummy service is down
/usr/bin/sv status /etc/service/30-dummy | grep down:
