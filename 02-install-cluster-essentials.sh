#!/bin/zsh

source 00-functions.sh

loadSetting '.essentials.pivotal_api_token' 'PIVOTAL_API_TOKEN'
loadSetting '.supervisor.hostname' 'KUBECTX_SV_CLUSTER'
loadSetting '.essentials.version' 'CLUSTER_ESSENTIALS_VERSION'
loadSetting '.essentials.bundle' 'INSTALL_BUNDLE'
loadSetting '.essentials.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.essentials.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.essentials.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

function download_cluster_essentials(){
    if [[ ! -f "downloads/tanzu-cluster-essentials-linux-amd64-$1.tgz" ]]; then
        info "Downloading cluster essentials"
        pivnet login --api-token=$PIVOTAL_API_TOKEN
        pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version=$1 --product-file-id=1330470
        mv tanzu-cluster-essentials-linux-amd64-$1.tgz downloads/tanzu-cluster-essentials-linux-amd64-$1.tgz
    else
        info "Cluster essentials already downloaded - Skipping!"
    fi
}

function unpack_cluster_essentials() {
    info "Unpacking cluster essentials"

    mkdir -p downloads/tanzu-cluster-essentials
    tar -xvf downloads/tanzu-cluster-essentials-linux-amd64-$1.tgz -C downloads/tanzu-cluster-essentials
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

    downloads/tanzu-cluster-essentials/kapp deploy --app tap-install-ns -n tanzu-cluster-essentials --file \
    <(\
        kubectl create namespace tap-install \
        --dry-run=client \
        --output=yaml \
        --save-config \
    ) --yes

    success "Cluster essentials successfully installed on $1."
}

download_cluster_essentials $CLUSTER_ESSENTIALS_VERSION
unpack_cluster_essentials $CLUSTER_ESSENTIALS_VERSION

if [ -z $1 ] ; then
    loginToViewCluster
    install_cluster_essentials $KUBECTX_VIEW_CLUSTER
    loginToBuildCluster
    install_cluster_essentials $KUBECTX_BUILD_CLUSTER
    loginToRunCluster
    install_cluster_essentials $KUBECTX_RUN_CLUSTER
else
    install_cluster_essentials $1
fi