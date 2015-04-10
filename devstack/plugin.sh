#!/bin/bash

# Copyright 2015 Midokura SARL
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is meant to be sourced from devstack.  It is a wrapper of
# devmido scripts that allows proper exporting of environment variables.

ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

if [[ "$1" == "stack" ]]; then

    if [[ "$2" == "pre-install" ]]; then

        source $ABSOLUTE_PATH/functions

        # Clone and build midonet service
        ERROR_ON_CLONE_BAK=$ERROR_ON_CLONE
        ERROR_ON_CLONE=False
        git_clone $MIDONET_REPO $MIDONET_DIR $MIDONET_BRANCH
        ERROR_ON_CLONE=$ERROR_ON_CLONE_BAK

        # Clone and build neutron midonet plugin
        PLUGIN_PATH=$ABSOLUTE_PATH/..

    elif [[ "$2" == "install" ]]; then

        export SERVICE_HOST=${MIDONET_SERVICE_HOST:?Error \$MIDONET_SERVICE_HOST is not set}
        export API_PORT=${MIDONET_API_PORT:?Error \$MIDONET_API_PORT is not set}
        export API_TIMEOUT=${MIDONET_API_TIMEOUT}
        export USE_CLUSTER=${USE_CLUSTER:-True}

        export TIMESTAMP_FORMAT
        export LOGFILE
        export USE_SCREEN
        export SCREEN_LOGDIR
        export MIDO_PASSWORD=$SERVICE_PASSWORD
        export TASKS_DB_USER=$DATABASE_USER
        export TASKS_DB_PASSWORD=$DATABASE_PASSWORD
        export CONFIGURE_LOGGING

        # Build neutron midonet plugin
        pip_install --no-deps --editable $ABSOLUTE_PATH/..

        # Build midonet client
        pip_install --editable $MIDONET_DIR/python-midonetclient

        # Run the command
        $MIDONET_DIR/tools/devmido/mido.sh

    elif [[ "$2" == "extra" ]]; then

        if [ "$MIDONET_ENABLE_Q_SVC_ONLY" == "False" ]; then
            export CIDR=${FLOATING_RANGE:?Error \$FLOATING_RANGE is not set}
            # TODO: Joe
            # We will not create the fake uplink until the re-arch work is done.
            # $MIDONET_DIR/tools/devmido/create_fake_uplink.sh
        fi


    elif [[ "$2" == "post-config" ]]; then

        # Set rootwrap.d to installed mm-ctl filters
        sudo cp $ABSOLUTE_PATH/midonet_rootwrap.filters /etc/neutron/rootwrap.d/

        midonet-db-manage upgrade head

        if is_service_enabled nova; then
            sudo cp $ABSOLUTE_PATH/midonet_rootwrap.filters /etc/nova/rootwrap.d/

            # Hack libvirt qemu conf to allow ethernet mode to run
            export LIBVIRT_QEMU_CONF='/etc/libvirt/qemu.conf'
            if [ ! $(sudo grep -q '^cgroup_device_acl' $LIBVIRT_QEMU_CONF) ]; then
                sudo bash -c "cat <<EOF >> $LIBVIRT_QEMU_CONF
cgroup_device_acl = [
    '/dev/null', '/dev/full', '/dev/zero',
    '/dev/random', '/dev/urandom',
    '/dev/ptmx', '/dev/kvm', '/dev/kqemu',
    '/dev/rtc', '/dev/hpet', '/dev/net/tun',
]
EOF"
                sudo service libvirt-bin restart
            fi
        fi
    fi

elif [[ "$1" == "unstack" ]]; then

    $MIDONET_DIR/tools/devmido/unmido.sh
    if [ "$MIDONET_ENABLE_Q_SVC_ONLY" == "False" ]; then
        CIDR=${FLOATING_RANGE:?Error \$FLOATING_RANGE is not set}
        # TODO: Joe
        # We will not create the fake uplink until the re-arch work is done.
        # $MIDONET_DIR/tools/devmido/delete_fake_uplink.sh
    fi
fi
