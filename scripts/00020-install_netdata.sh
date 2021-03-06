#!/bin/bash
# vim: et sr sw=4 ts=4 smartindent:
# install_netdata.sh
#
# ... only for rhel6 variants
#
# Installs
# * netdata (duh!)
# * installs tmp packages required for building
# * installs packages required for running netdata
# * uninstalls tmp packages if not already installed
#   prior to their installation.
#
# WHY IS NETDATA NOT AN RPM?
#   To retain its small footprint it needs to be rebuilt
#   any time the kernel or core-libs change
#
TMP_PKGS="
    autoconf
    automake
    gcc
    git
    libuuid-devel
    make
    pkgconfig
    zlib-devel
"
REQUIRED_PKGS="
    curl
    nodejs
"

NETDATA_GIT_TAG=v1.2.0
NETDATA_DISABLE_LOGS=${NETDATA_DISABLE_LOGS:-1}

TMP_PKGS_TO_ERASE=""

UPLOADS=/tmp/uploads/netdata

function is_installed {
    if yum list installed "$@" >/dev/null 2>&1; then
        true
    else
        false
    fi
}

echo "$0 INFO: ... installing netdata, awesome real-time dashboard"
echo "$0 INFO: ... checking required files uploaded"

if [[ ! -d $UPLOADS ]]; then
    echo "$0 ERROR: ... couldn't find uploads dir $UPLOADS" >&2
    exit 1
fi

echo "$0 INFO: ... checking epel repo is available"
if [[ ! -r /etc/yum.repos.d/epel.repo ]]; then
    echo "$0 ERROR: ... epel repo must be installed (even if disabled)"
    exit 1
fi

echo "$0 INFO: ... determining which tmp pkgs can be deleted after installing netdata"
for my_pkg in $TMP_PKGS; do
    if is_installed $my_pkg
    then
        echo "... won't remove pkg $my_pkg as installed prior to netdata."
    else
        echo "... will remove pkg $my_pkg after installing netdata."
        TMP_PKGS_TO_ERASE="$TMP_PKGS_TO_ERASE $my_pkg"
    fi
done

echo "$0 INFO: installing netdata."
yum install -y $TMP_PKGS $REQUIRED_PKGS --enablerepo epel     \
&& cd /var/tmp                                                \
&& git clone https://github.com/firehol/netdata.git --depth=1 \
&& cd netdata                                                 \
&& git checkout $NETDATA_GIT_TAG                              \
&& ./netdata-installer.sh <<< $'\n'                           \
&& yum remove -y $TMP_PKGS_TO_ERASE

echo "$0 INFO: ... checking if install was successful"
if pgrep netdata
then
    echo "$0: INFO: Looking good Billy Ray."
    if curl -s -o /dev/null --max-time 2 http://localhost:19999
    then
        echo "$0: INFO: Feeling good Lewis."
        if [[ -w /sys/kernel/mm/ksm ]]; then 
            echo "$0 INFO: found ksm params under /sys/kernel. Will tune."
            echo "$0 INFO: ... this will only provide limited benefit"
            echo "$0 INFO:     if ksm service is not running (yum: qemu-kvm)"
            echo 1    >/sys/kernel/mm/ksm/run
            echo 1000 >/sys/kernel/mm/ksm/sleep_millisecs
        fi
    else
        echo "$0 ERROR: ... curling localhost:19999 did not bring back netdata."
        echo "$0 ERROR: Installation unsuccessful."
        exit 1
    fi
else
    echo "$0 ERROR: ... can't find netdata process running."
    echo "$0 ERROR: Installation unsuccessful."
    exit 1
fi

# DISABLE all netdata logs - we don't care enough to logrotate ...
if [[ $NETDATA_DISABLE_LOGS -eq 1 ]]; then
    echo "$0 INFO: ... changing netdata.conf to select no logs."
    for log_type in access debug error; do
        echo "$0 INFO: ... disabling $log_type."
        sed -i "s/^\([ \t]*\)#\( *$log_type log *= \).*/\1\2none/" /etc/netdata/netdata.conf
    done
fi

# ... copy over overlay files and shutdown
cp -r $UPLOADS/* /
chkconfig netdata on
service netdata stop

exit 0
