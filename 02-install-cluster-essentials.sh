#!/bin/zsh

source 00-functions.sh

loadSetting '.essentials.version' 'CLUSTER_ESSENTIALS_VERSION'
loadSetting '.essentials.bundle' 'INSTALL_BUNDLE'
loadSetting '.essentials.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.essentials.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.essentials.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

function unpack_cluster_essentials() {
    info "Unpacking cluster essentials"

    mkdir -p downloads/tanzu-cluster-essentials
    tar -xvf downloads/tanzu-cluster-essentials-darwin-amd64-$1.tgz -C downloads/tanzu-cluster-essentials
}

function install_cluster_essentials() {
    info "Installing cluster essentials on $1"

    kubectx $1

    kubectl create clusterrolebinding default-tkg-admin-privileged-binding \
        --clusterrole=psp:vmware-system-privileged \
        --group=system:authenticated \
        --dry-run=client -o yaml | kubectl apply -f -

    cd downloads/tanzu-cluster-essentials
    ./install.sh --yes
    cd ../../

    kapp deploy --app tap-install-ns -n tanzu-cluster-essentials --file \
    <(\
        kubectl create namespace tap-install \
        --dry-run=client \
        --output=yaml \
        --save-config \
    ) --yes

    success "Cluster essentials successfully installed on $1."
}

unpack_cluster_essentials $CLUSTER_ESSENTIALS_VERSION

if [ -z $1 ] ; then
    install_cluster_essentials $KUBECTX_VIEW_CLUSTER
    install_cluster_essentials $KUBECTX_BUILD_CLUSTER
    install_cluster_essentials $KUBECTX_RUN_CLUSTER
else
    install_cluster_essentials $1
fi