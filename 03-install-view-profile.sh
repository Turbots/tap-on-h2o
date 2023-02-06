#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.profiles.view' 'VIEW_PROFILE'

loadSetting '.tap.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.tap.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.tap.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

loadSetting '.essentials.registry.hostname' 'ESSENTIALS_REGISTRY_HOSTNAME'
loadSetting '.tap.developer.registry.hostname' 'DEV_REGISTRY_HOSTNAME'

loadSetting '.harbor.version' 'HARBOR_VERSION'

function install_tap_view_profile() {
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

    ytt -f "$VALUES_DIR/view/$VIEW_PROFILE" -f "$VALUES_DIR/default.yaml" --ignore-unknown-comments > "$GENERATED_DIR/$VIEW_PROFILE"

    info "Installing TAP $TAP_VERSION"

    tanzu package install tap -n tap-install \
        --package-name tap.tanzu.vmware.com \
        --version $TAP_VERSION \
        --values-file "$GENERATED_DIR/$VIEW_PROFILE"

    info "Configuring automated DNS certificates"

    kapp deploy -n tap-install -a lets-encrypt-issuer \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/letsencrypt.yaml --ignore-unknown-comments \
        ) --yes

    kapp deploy -n tap-install -a certificates \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/view/certificates.yaml --ignore-unknown-comments \
        ) --yes
}

function install_harbor() {
    tanzu package repository add tanzu-standard --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.0 -n tap-install

    ytt -f "$VALUES_DIR/view/harbor.yaml" -f "$VALUES_DIR/default.yaml" --ignore-unknown-comments > "$GENERATED_DIR/harbor.yaml"

    tanzu package install harbor -n tap-install \
        --package-name harbor.tanzu.vmware.com \
        --version $HARBOR_VERSION \
        --values-file $GENERATED_DIR/harbor.yaml

    kapp deploy -n tap-install -a harbor-overlay --file \
    <(\
        kubectl -n tap-install create secret generic harbor-overlay \
          -o yaml \
          --dry-run=client \
          --from-file=$VALUES_DIR/view/harbor-overlay.yaml
    ) --yes

    kubectl -n tap-install annotate packageinstalls harbor ext.packaging.carvel.dev/ytt-paths-from-secret-name.1=harbor-overlay --overwrite
    kubectl delete pods -l app=harbor -n tanzu-system-registry

    info "Harbor installed successfully on $1"
}

function relocate_images_for_tds() {
    kapp deploy -n tap-install -a relocate-job \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/view/harbor-job.yaml --ignore-unknown-comments \
        ) --yes
}

loginToViewCluster

info "Installing TAP View Profile on $KUBECTX_VIEW_CLUSTER"
install_tap_view_profile

info "Installing Harbor on $KUBECTX_VIEW_CLUSTER"
install_harbor

info "Relocating Tanzu Data Services container images from $ESSENTIALS_REGISTRY_HOSTNAME to $DEV_REGISTRY_HOSTNAME."
relocate_images_for_tds

success "TAP installation on $KUBECTX_VIEW_CLUSTER has completed."