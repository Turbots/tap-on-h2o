#!/bin/zsh

set -e
setopt aliases

autoload colors; colors

function loadSetting() {
    var=`yq $1 values/default.yaml`
    export $2=$var

    if [[ $3 == "-p" ]] ; then
        info "Loaded env variable $2 = *****"
    else 
        info "Loaded env variable $2 = $var"
    fi
}

function error() {
    println red "ERROR" $1
}

function warn() {
    print magenta "WARN" $1
}

function info() {
    println yellow "INFO" $1
}

function success() {
    println green "SUCCESS" $1
}

function print() {
    local paddedString=`(printf %-8s $2)`
    echo $fg[$1]"|$paddedString|"$reset_color" $3"
}

function println() {
    local paddedString=`(printf %-8s $2)`
    echo "\n"$fg[$1]"|$paddedString|"$reset_color" $3"
}

function createDirectory() {
    [ -d $1 ] || mkdir -p $1
}

function determinePlatform() {
    if [ "$(uname)" = "Darwin" ]; then
        info "Platform is Mac."
        determineIfSiliconMac
        export PLATFORM="darwin"
    elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then
        info "Platform is Linux."
        export PLATFORM="linux"
    else
        warn "We don't support MINGW64_NT environments."
    fi
}

function determineIfSiliconMac() {
    if [[ $(uname -m) == 'arm64' ]]; then
        export SILICON_MAC="true"
        info "Mac has an Apple Silicon chip (ARM64 based)."
    fi
}

function install_vsphere_plugin() {
    createDirectory downloads

    if [ ! -f "downloads/vsphere-plugin-$PLATFORM.zip" ]; then
        info "Downloading Kubectl vSphere plugin for $PLATFORM"
        wget -O downloads/vsphere-plugin-$PLATFORM.zip https://$1/wcp/plugin/$PLATFORM-amd64/vsphere-plugin.zip --no-check-certificate
    fi
    info "Installing Kubectl vSphere plugin for $PLATFORM"
    unzip -o downloads/vsphere-plugin-$PLATFORM.zip -d downloads
    export PATH="$PATH:$PWD/downloads/bin"

    success "Kubectl vSphere Plugin installed"
}

function loginToSupervisor() {
    info "Logging in to supervisor cluster $1"

    kubectl vsphere login -v 0 --server=$1 --insecure-skip-tls-verify -u administrator@vsphere.local

    success "Logged in to supervisor cluster $1."
}

function loginToCluster() {
    info "Logging in to $3 in vSphere namespace $2"

    kubectl vsphere login --server=$1 --insecure-skip-tls-verify -u administrator@vsphere.local --tanzu-kubernetes-cluster-namespace $2 --tanzu-kubernetes-cluster-name $3

    success "Logged in to $3."
}

function loginToViewCluster() {
    loginToCluster $KUBECTX_SV_CLUSTER $SV_NS_NON_PROD $KUBECTX_VIEW_CLUSTER
}

function loginToBuildCluster() {
    loginToCluster $KUBECTX_SV_CLUSTER $SV_NS_NON_PROD $KUBECTX_BUILD_CLUSTER
}

function loginToRunCluster() {
    loginToCluster $KUBECTX_SV_CLUSTER $SV_NS_PROD $KUBECTX_RUN_CLUSTER
}

function loginToAllClusters() {
    loginToSupervisor
    loginToViewCluster
    loginToBuildCluster
    loginToRunCluster
}

determinePlatform

loadSetting '.supervisor.hostname' 'KUBECTX_SV_CLUSTER'
loadSetting '.supervisor.password' 'KUBECTL_VSPHERE_PASSWORD' '-p'
loadSetting '.supervisor.namespaces.prod' 'SV_NS_PROD'
loadSetting '.supervisor.namespaces.nonprod' 'SV_NS_NON_PROD'

loadSetting '.tap.view.cluster' 'KUBECTX_VIEW_CLUSTER'
loadSetting '.tap.build.cluster' 'KUBECTX_BUILD_CLUSTER'
loadSetting '.tap.run.cluster' 'KUBECTX_RUN_CLUSTER'

loadSetting '.tap.version' 'TAP_VERSION'

export GENERATED_DIR="generated"
export VALUES_DIR="values"

success "Settings Initialized"