#!/bin/zsh

source 00-functions.sh

function deploy_clusters() {
    info "Provisioning workload clusters in Supervisor Cluster $1"

    kubectx $1
    
    kubectl apply -f clusters/$SV_NS_NON_PROD/$KUBECTX_VIEW_CLUSTER.yaml -n $SV_NS_NON_PROD
    kubectl apply -f clusters/$SV_NS_NON_PROD/$KUBECTX_BUILD_CLUSTER.yaml -n $SV_NS_NON_PROD
    kubectl apply -f clusters/$SV_NS_PROD/$KUBECTX_RUN_CLUSTER.yaml -n $SV_NS_PROD
}

loginToSupervisor $KUBECTX_SV_CLUSTER

deploy_clusters $KUBECTX_SV_CLUSTER

success "Cluster provisioning initialized!"