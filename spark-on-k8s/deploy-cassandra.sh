#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -o errexit -o pipefail

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${CURR_DIR}/utils.sh

DEFAULT_K8S_NAMESPACE="cassandra"
DEFAULT_CLUSTER_NAME="cassandra"

function namespace_exists {
  # verify that the namespace exists
  local ns_exists=`kubectl get namespace $@ --no-headers --output=go-template={{.metadata.name}} 2>/dev/null`
  [ ! -z "${ns_exists}" ]
}

function check_requirements {
  command_exists_or_err kubectl
  command_exists_or_err helm
}

function deploy {
  check_requirements

  echo "Adding the 'incubator' Helm repo..."
  helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/

  echo "Deploying Cassandra cluster named ${CLUSTER_NAME} to the namespace ${K8S_NAMESPACE}..."
  helm install \
    ${CLUSTER_NAME} incubator/cassandra \
    --namespace ${K8S_NAMESPACE} \
    --set config.cluster_size=2,config.max_heap_size=1024M,persistence.size=1Gi \
    --debug ${DRY_RUN}
}

function destory {
  check_requirements

  echo "Destorying Cassandra cluster named ${CLUSTER_NAME}..."
  helm delete --purge ${CLUSTER_NAME}
}

function usage {
  cat <<EOF
$0 deploys or destroys Cassandra cluster on Kubernetes.

Usage:  $0 [--deploy|--destroy]

Options:

  --help           This help.

  --deploy         Deploys Cassandra on Kubernetes via helm.

  --destroy        Destroys Cassandra Helm Chart.

  -ns|--namespace  The Kubernetes namespace to use (defalt: ${DEFAULT_K8S_NAMESPACE}).

  -n|--name        The name of the Cassandra cluster (default: ${DEFAULT_CLUSTER_NAME}).

  -dry-run         Specify to run the chart in dry-run mode.

Examples:

  - Deploys with the default name (${DEFAULT_CLUSTER_NAME}) to the default namespace (${DEFAULT_K8S_NAMESPACE}).
    sh $0 --deploy

  - Destroys the cluster with the default name (${DEFAULT_CLUSTER_NAME}).
    sh $0 --destroy

  - Deploys with the custom name to the custom namespace.
    sh $0 --deploy --namespace my-cassandra --name cassandra-cluster

  - Destroys the cluster with non-default name.
    sh $0 --destroy --name cassandra-cluster # destroys Cassandra cluster

EOF
}

PRINT_HELP=false
DEPLOY=false
DESTROY=false
K8S_NAMESPACE=${DEFAULT_K8S_NAMESPACE}
CLUSTER_NAME=${DEFAULT_CLUSTER_NAME}
DRY_RUN=""

# Note that getopt is not so MacOS-friendly.
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
  -h|--help)
    PRINT_HELP=true
    shift
    ;;
  --deploy)
    DEPLOY=true
    shift
    ;;
  --destroy)
    DESTROY=true
    shift
    ;;
  -ns|--namespace)
    K8S_NAMESPACE="$2"
    shift 2
    ;;
  -n|--name)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  --dry-run)
    DRY_RUN="--dry-run"
    shift
    ;;
  --)
    shift
    break
    ;;
  *) # unknown option
    echo "Unknow arg ${key}"
    shift
    ;;
esac
done

if "${PRINT_HELP}"; then
  usage
  exit 0
fi

if "${DEPLOY}"; then
  deploy
  exit 0
fi

if "${DESTROY}"; then
  destory
  exit 0
fi
