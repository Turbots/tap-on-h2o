#!/bin/zsh

source 00-functions.sh

function delete_clusters() {
    info "Delete workload clusters in Supervisor Cluster $1"

    kubectx $1
    
    kubectl delete -f clusters/view-cluster.yaml -n $SV_NS_NON_PROD --wait=false
    kubectl delete -f clusters/build-cluster.yaml -n $SV_NS_NON_PROD --wait=false
    kubectl delete -f clusters/run-cluster.yaml -n $SV_NS_PROD --wait=false
}

install_vsphere_plugin $KUBECTX_SV_CLUSTER

loginToSupervisor $KUBECTX_SV_CLUSTER

delete_clusters $KUBECTX_SV_CLUSTER

success "Clusters Deleted!"