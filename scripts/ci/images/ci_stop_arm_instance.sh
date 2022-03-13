#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# shellcheck source=scripts/ci/libraries/_script_init.sh
. "$( dirname "${BASH_SOURCE[0]}" )/../libraries/_script_init.sh"

# This is an AMI that is based on Basic Amazon Linux AMI with installed and configured docker service
WORKING_DIR="/tmp/armdocker"
INSTANCE_INFO="${WORKING_DIR}/instance_info.json"
REGION="us-east-2"
SECURITY_GROUP=$(jq < "${INSTANCE_INFO}" ".Instances[0].NetworkInterfaces[0].Groups[0].GroupId" -r)
METADATA_ADDRESS="http://169.254.169.254/latest/meta-data"
MAC_ADDRESS=$(curl -s "${METADATA_ADDRESS}/network/interfaces/macs/" | head -n1 | tr -d '/')
CIDR=$(curl -s "${METADATA_ADDRESS}/network/interfaces/macs/${MAC_ADDRESS}/vpc-ipv4-cidr-block/")
AUTOSSH_PIDFILE="${WORKING_DIR}/autossh.pid"
AUTOSSH_LOGFILE="${WORKING_DIR}/autossh.log"

function stop_arm_instance() {
    if [[ ! -f "${INSTANCE_INFO}" ]]; then
        echo "${COLOR_YELLOW}Skip killing ARM instance as it has not been started.${COLOR_RESET}"
        return
    fi
    kill "$(cat "${AUTOSSH_PIDFILE}")" || true
    INSTANCE_ID=$(jq < "${INSTANCE_INFO}" ".Instances[0].InstanceId" -r)
    aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}"
    aws ec2 revoke-security-group-ingress --region "${REGION}" --group-id "${SECURITY_GROUP}" \
                --protocol tcp --port 22 --cidr "${CIDR}" || true
    echo "################################"
    echo "  AutoSSH Log"
    echo "################################"
    cat "${AUTOSSH_LOGFILE}" || true
}

stop_arm_instance
