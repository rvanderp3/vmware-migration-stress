#!/bin/bash

SECRET_PATH=/tmp

oc extract secret/vsphere-creds -n kube-system --to=${SECRET_PATH}

WORKSPACE="$(oc get cm cloud-provider-config -n openshift-config -o jsonpath='{.data.config}' | head -n 10 | tomljson | jq '.Workspace')"


export GOVC_INSECURE=1
export GOVC_URL="$(echo ${WORKSPACE} | jq '.server' | tr -d '"')"
export GOVC_DATACENTER="$(echo ${WORKSPACE} | jq '.datacenter' | tr -d '"' )"
export GOVC_DATASTORE="$(echo ${WORKSPACE} | jq '.["default-datastore"]' | tr -d '"')"
export GOVC_USERNAME="$(<$SECRET_PATH/${GOVC_URL}.username)" 
export GOVC_PASSWORD="$(<$SECRET_PATH/${GOVC_URL}.password)" 


function migrate() {
    HOSTS=($(govc ls -t HostSystem "/${GOVC_DATACENTER}/host/*"))
    HOSTCOUNT="${#HOSTS[@]}"
    NODES=$(oc get node -o jsonpath='{.items[*].metadata.name}' -l node-role.kubernetes.io/worker)

    for N in ${NODES} 
    do  
        loc=$((RANDOM % ${HOSTCOUNT}))
        host=${HOSTS[$loc]}
        echo "array: ${loc} host: ${host}"  
        govc vm.migrate -host $host ${N} 
    done
}

function random_migrate() {
    while true; do
        migrate
        sleep $((30+RANDOM % 60)) 
    done
}

function shutdownNode() {
    NODE_NAME=$1
    oc adm drain $NODE_NAME
    govc vm.power -off=true $NODE_NAME
}

function startNode() {
    NODE_NAME=$1
    govc vm.power -on=true $NODE_NAME
    oc adm uncordon $NODE_NAME
}

function randomNodeSelection() {
    NODES=($1)
    AVAILABLE_NODE_COUNT=${#NODES[@]}
    NODE_ACTION_COUNT=$(((RANDOM % ($AVAILABLE_NODE_COUNT - 1))+1))        
    NODES_SELECTED=""
    for (( I=1; I<=$NODE_ACTION_COUNT; I++ ))
    do  
        AVAILABLE_NODE_COUNT=${#NODES[@]}        
        NODE_INDEX_TO_SELECT=$((RANDOM % $AVAILABLE_NODE_COUNT))
        NODE_NAME_TO_SELECT=${NODES[$NODE_INDEX_TO_SELECT]}
        NODES=( ${NODES[@]/$NODE_NAME_TO_SELECT} )
        NODES_SELECTED="$NODES_SELECTED $NODE_NAME_TO_SELECT"
    done
    echo $NODES_SELECTED
}

function randomDrainAndShutdownVms() {    
    NODE_LIST=$(oc get nodes -l node-role.kubernetes.io/worker -o=jsonpath='{.items[*].metadata.name}')
    while [ 1 ]; do
        NODES=$(randomNodeSelection "$NODE_LIST")

        for NODE in $NODES; do
            echo Draining and shutting down node $NODE
            shutDownNode $NODE
        done
        TIME_TO_SLEEP=$(((RANDOM % 300)+30))
        echo Waiting $TIME_TO_SLEEP seconds before restarting nodes
        sleep $TIME_TO_SLEEP

        for NODE in $NODES; do
            echo Restarting node $NODE
            startNode $NODE
        done
        echo Waiting 3 minutes before next node shutdown
        sleep 180
    done
}

random_migrate &
randomDrainAndShutdownVms &

openshift-tests run openshift/conformance/parallel -o /projects/output/e2e.log

# kill migration stress tests
kill $(jobs -p)