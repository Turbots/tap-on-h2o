#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.profiles.build' 'BUILD_PROFILE'

loadSetting '.tap.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.tap.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.tap.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

loadSetting '.tap.developer.namespace' 'DEVELOPER_NAMESPACE'
loadSetting '.tap.developer.registry.hostname' 'DEVELOPER_REGISTRY_HOSTNAME'
loadSetting '.tap.developer.registry.username' 'DEVELOPER_REGISTRY_USERNAME'
loadSetting '.tap.developer.registry.password' 'DEVELOPER_REGISTRY_PASSWORD' '-p'

loadSetting '.gitops_repository.server_address' 'GITOPS_SERVER'
loadSetting '.gitops_repository.owner' 'GITOPS_OWNER'
loadSetting '.gitops_repository.access_token' 'GITOPS_TOKEN' '-p'

function install_tap_build_profile() {
    info "Installing TAP on $1"

    kubectx $1

    mkdir -p $GENERATED_DIR

    info "Adding $INSTALL_REGISTRY_HOSTNAME as the main registry secret"

    tanzu secret registry -n tap-install add tap-registry \
        --server "${INSTALL_REGISTRY_HOSTNAME}" \
        --username "${INSTALL_REGISTRY_USERNAME}" \
        --password "${INSTALL_REGISTRY_PASSWORD}" \
        --export-to-all-namespaces \
        --yes

    info "Configuring TAP $TAP_VERSION repository"
    
    tanzu package repository -n tap-install add tanzu-tap-repository \
        --url $INSTALL_REGISTRY_HOSTNAME/tanzu-application-platform/tap-packages:$TAP_VERSION

    ytt -f "$VALUES_DIR/build/$BUILD_PROFILE" -f "$VALUES_DIR/default.yaml" --ignore-unknown-comments > "$GENERATED_DIR/$BUILD_PROFILE"

    info "Installing TAP $TAP_VERSION"

    tanzu package install tap -n tap-install \
        --package-name tap.tanzu.vmware.com \
        --version $TAP_VERSION \
        --values-file "$GENERATED_DIR/$BUILD_PROFILE"

    info "Configuring Metadata store connection"

    kapp deploy --app metadata-store-secret-export -n tap-install \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/build/metadata-store-secret-export.yaml --ignore-unknown-comments \
        ) --yes

    kapp deploy --app tap-gui-rbac -n tap-install \
        --file $VALUES_DIR/tap-gui-viewer-service-account-rbac.yaml \
        --yes
    
    info "Configuring developer namespace ${DEVELOPER_NAMESPACE}"

    kapp deploy --app "tap-dev-ns-${DEVELOPER_NAMESPACE}" -n tap-install \
        --file <(\
            kubectl create namespace "${DEVELOPER_NAMESPACE}" \
            --dry-run=client \
            --output=yaml \
            --save-config \
        ) --yes

    kapp deploy --app git-secret -n tap-install \
        --file <(\ 
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/build/git-secret.yaml --ignore-unknown-comments \
        ) --yes

    tanzu secret registry -n ${DEVELOPER_NAMESPACE} add dev-registry \
        --server "${DEVELOPER_REGISTRY_HOSTNAME}" \
        --username "${DEVELOPER_REGISTRY_USERNAME}" \
        --password "${DEVELOPER_REGISTRY_PASSWORD}" \
        --yes

     kapp deploy --app developer-sa-rbac -n ${DEVELOPER_NAMESPACE} \
        --file $VALUES_DIR/build/permissions.yaml \
        --yes
}

function setup_store_ca() {
    info "Fetching metadata store token from $1"

    kubectx $1

    export STORE_ca__crt=$(kubectl get secret contour-tls-delegation-cert -n tanzu-system-ingress -o json | jq -r ".data.\"tls.crt\"")
    export STORE_auth__token=$(kubectl get secrets metadata-store-read-write-client -n metadata-store -o jsonpath="{.data.token}")

    info "Configuring metadata store token in $2"

    kubectx $2

    kapp deploy --app metadata-store -n tap-install \
        --file <(\
            ytt --data-values-env STORE -f $VALUES_DIR/build/store.yaml \
        ) --yes
}

install_tap_build_profile $KUBECTX_BUILD_CLUSTER
setup_store_ca $KUBECTX_VIEW_CLUSTER $KUBECTX_BUILD_CLUSTER

success "TAP installation on $KUBECTX_BUILD_CLUSTER completed."