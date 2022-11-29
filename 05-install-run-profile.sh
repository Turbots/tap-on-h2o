#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.developer.namespace' 'DEVELOPER_NAMESPACE'

loadSetting '.tap.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.tap.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.tap.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

loadSetting '.tap.developer.registry.hostname' 'REGISTRY_HOSTNAME'
loadSetting '.tap.developer.registry.project' 'REGISTRY_PROJECT'
loadSetting '.tap.developer.registry.username' 'REGISTRY_USERNAME'
loadSetting '.tap.developer.registry.password' 'REGISTRY_PASSWORD' '-p'

function install_tap_run_profile() {
    kubectx $1

    mkdir -p $GENERATED_DIR

    tanzu secret registry -n tap-install add tap-registry \
        --server "${INSTALL_REGISTRY_HOSTNAME}" \
        --username "${INSTALL_REGISTRY_USERNAME}" \
        --password "${INSTALL_REGISTRY_PASSWORD}" \
        --export-to-all-namespaces \
        --yes

    info "Configuring TAP $TAP_VERSION repository"

    tanzu package repository -n tap-install add tanzu-tap-repository \
        --url $INSTALL_REGISTRY_HOSTNAME/tanzu-application-platform/tap-packages:$TAP_VERSION

    ytt -f "$VALUES_DIR/run/run.yaml" -f "$VALUES_DIR/default.yaml" --ignore-unknown-comments > "$GENERATED_DIR/run.yaml"

    info "Installing TAP $TAP_VERSION"

    tanzu package install tap -n tap-install \
        --package-name tap.tanzu.vmware.com \
        --version $TAP_VERSION \
        --values-file "$GENERATED_DIR/run.yaml"

    info "Configuring permissions for deliverables"

    kapp deploy --app tap-gui-rbac -n tap-install \
        --file $VALUES_DIR/tap-gui-viewer-service-account-rbac.yaml \
        --yes

    kapp deploy --app "tap-dev-ns-${DEVELOPER_NAMESPACE}" -n tap-install \
        --file <(\
            kubectl create namespace "${DEVELOPER_NAMESPACE}" \
            --dry-run=client \
            --output=yaml \
            --save-config \
        ) --yes

    kapp deploy --app git-secret -n tap-install \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/run/git-secret.yaml --ignore-unknown-comments \
        ) --yes

    tanzu secret registry -n ${DEVELOPER_NAMESPACE} add registry-credentials \
        --server "${REGISTRY_HOSTNAME}/${REGISTRY_PROJECT}" \
        --username "${REGISTRY_USERNAME}" \
        --password "${REGISTRY_PASSWORD}" \
        --yes

    kapp deploy --app permissions -n ${DEVELOPER_NAMESPACE} \
        --file $VALUES_DIR/run/permissions.yaml \
        --yes
}

loginToRunCluster

info "Installing TAP View Profile on $KUBECTX_RUN_CLUSTER"
install_tap_run_profile $KUBECTX_RUN_CLUSTER

success "TAP installation on $KUBECTX_RUN_CLUSTER completed."