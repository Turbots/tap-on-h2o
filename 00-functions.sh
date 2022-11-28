#!/bin/zsh

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
    echo "\n"$fg[$1]"|$paddedString|"$reset_color" $3\n"
}

function install_vsphere_plugin() {
    info "Downloading and install Kubectl vSphere plugin"

    if [[ ! -f "/home/vscode/.local/bin/kubectl-vsphere" ]]; then
    wget -O downloads/vsphere-plugin.zip https://$1/wcp/plugin/linux-amd64/vsphere-plugin.zip --no-check-certificate

    mkdir -p /home/vscode/.local
    unzip -o downloads/vsphere-plugin.zip -d downloads
    mv -f downloads/bin /home/vscode/.local
    #rm vsphere-plugin.zip

    success "Plugin installed"
    fi
    info "Plugin already installed - Skipping"
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

if [ $# -eq 2 ] ; then
    info "Fetching fresh tokens for cluster $2"
    
    loginToSupervisor $KUBECTX_SV_CLUSTER
    loginToCluster $KUBECTX_SV_CLUSTER $1 $2
else
    warn "Usage: ./00-functions.sh <VSPHERE_NAMESPACE> <CLUSTER_NAME>"
fi

success "Initialized"
