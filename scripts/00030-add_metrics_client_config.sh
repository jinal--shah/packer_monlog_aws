#!/bin/bash
# vim: et sr sw=4 ts=4 smartindent:
#
# add_metrics_client_config.sh
#
# Installs:
#
# * cob (cob.py, yum plugin to treat S3 as a repo)
# * RPMs to provide these services:
#   * statsite (statsd replacement),
#   * collectd,
#   * carbon relay (which feeds to METRICS_REMOTE_HOST:METRICS_REMOTE_PORT)
#
# The services will be turned off by default.
# On instance-up we expect the carbon-c-relay to be configured correctly
# with runtime vars e.g. aws instance-id
# The services should be started after this happens
# (and then set to start on boot)
#
UPLOADS=/tmp/uploads/metrics
METRICS_YUM_CONF=etc/yum.repos.d/metrics.repo

METRICS_RPMS="
    carbon-c-relay
    collectd
    collectd-disk
    collectd-dns
    collectd-netlink
    collectd-rrdtool
    collectd-utils
    statsite
"

function is_installed {
    if yum list installed "$@" >/dev/null 2>&1; then
        true
    else
        false
    fi
}

echo "$0 INFO: ... installing metrics clients"
echo "$0 INFO: ... checking required files uploaded"

if [[ ! -d $UPLOADS ]]; then
    echo "$0 ERROR: ... couldn't find uploads dir $UPLOADS" >&2
    exit 1
fi

# ... install
cp $UPLOADS/$METRICS_YUM_CONF /$METRICS_YUM_CONF        \
&& yum-config-manager --enable eurostar_prod >/dev/null \
&& yum -y install $METRICS_RPMS                         \
&& mkdir -p /etc/collectd.d                             \
&& cp -r $UPLOADS/* /                                   \
&& yum-config-manager --disable eurostar_prod >/dev/null

# ... check pkgs are installed
for pkg in $METRICS_RPMS; do
    if ! is_installed $pkg
    then
        echo "$0 ERROR: pkg $pkg not installed ..." >&2
        rc=1
    fi
done

[[ $rc -eq 1 ]] && exit 1

# ... can't verify until instance is up and service configured
for service in carbon-c-relay collectd statsite; do
    service $service stop >/dev/null 2>&1
    chkconfig $service off
done

# ... cleanup
rm -rf $UPLOADS

exit 0
