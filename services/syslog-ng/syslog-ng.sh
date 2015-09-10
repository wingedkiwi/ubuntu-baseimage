#!/bin/bash
set -e
source /bd_build/buildconfig
set -x

SYSLOG_NG_BUILD_PATH=/bd_build/services/syslog-ng

## Install a syslog daemon.
$minimal_apt_get_install syslog-ng-core
mkdir /etc/service/10-syslog-ng
cp $SYSLOG_NG_BUILD_PATH/syslog-ng.runit /etc/service/10-syslog-ng/run
cp $SYSLOG_NG_BUILD_PATH/syslog-ng.check /etc/service/10-syslog-ng/check

mkdir -p /var/lib/syslog-ng
cp $SYSLOG_NG_BUILD_PATH/syslog_ng_default /etc/default/syslog-ng
touch /var/log/syslog
chmod u=rw,g=r,o= /var/log/syslog
cp $SYSLOG_NG_BUILD_PATH/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf

## Install syslog to "docker logs" forwarder.
mkdir /etc/service/10-syslog-forwarder
cp $SYSLOG_NG_BUILD_PATH/syslog-forwarder.runit /etc/service/10-syslog-forwarder/run

## Install logrotate.
$minimal_apt_get_install logrotate
cp $SYSLOG_NG_BUILD_PATH/logrotate_syslogng /etc/logrotate.d/syslog-ng
