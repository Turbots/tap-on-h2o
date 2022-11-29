#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.profiles.view' 'VIEW_PROFILE'

function update_cluster_locator_info() {
    kubectx $1
    
    export CLUSTER_name=$1
    export CLUSTER_url=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    export CLUSTER_token=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=json \
        | jq -r '.secrets[0].name') -o=json \
        | jq -r '.data["token"]' \
        | base64 --decode)
    
    ytt --data-values-env CLUSTER -f $GENERATED_DIR/$VIEW_PROFILE -f $VALUES_DIR/view/cluster-locator-overlay.yaml > $GENERATED_DIR/tmp.yaml
    cp $GENERATED_DIR/tmp.yaml $GENERATED_DIR/$VIEW_PROFILE
    rm $GENERATED_DIR/tmp.yaml
}

function update_metadata_store_token() {
    kubectx $1

    export BEARER_TOKEN=$(kubectl get secrets metadata-store-read-write-client -n metadata-store -o jsonpath="{.data.token}" | base64 -d)
    
    ytt --data-value bearer_token=$BEARER_TOKEN -f $GENERATED_DIR/$VIEW_PROFILE -f $VALUES_DIR/view/metadata-store-token-overlay.yaml > $GENERATED_DIR/tmp.yaml
    cp $GENERATED_DIR/tmp.yaml $GENERATED_DIR/$VIEW_PROFILE
    rm $GENERATED_DIR/tmp.yaml
}

function update_view_cluster() {
    kubectx $1

    tanzu package install tap -n tap-install \
        --package-name tap.tanzu.vmware.com \
        --version $TAP_VERSION \
        --values-file "$GENERATED_DIR/$VIEW_PROFILE"
}

loginToViewCluster
loginToBuildCluster
loginToRunCluster

info "Updating metadata store Bearer Token so $1 can display CVE information in the GUI."
update_metadata_store_token $KUBECTX_VIEW_CLUSTER

update_cluster_locator_info $KUBECTX_BUILD_CLUSTER
update_cluster_locator_info $KUBECTX_RUN_CLUSTER

info "Updating view cluster configuration."
update_view_cluster $KUBECTX_VIEW_CLUSTER

success "View cluster should be able to connect to all your build and run clusters now."

warn "Add the following token to your tap_gui.app_config.proxy./metadata-store.headers.Authorization section in the view/view.yaml:"

yq '.tap_gui.app_config.proxy./metadata-store.headers.Authorization' generated/view.yaml

warn "Add the following snippet to your tap_gui.app_config.kubernetes.clusterLocatorMethods section in the view/view.yaml:"

yq '.tap_gui.app_config.kubernetes.clusterLocatorMethods[0].clusters[]' generated/view.yaml