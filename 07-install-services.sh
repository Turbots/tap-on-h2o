#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.developer.namespace' 'DEVELOPER_NAMESPACE'

loadSetting '.essentials.registry.hostname' 'ESSENTIALS_REGISTRY_HOSTNAME'

loadSetting '.tap.developer.registry.hostname' 'REGISTRY_HOSTNAME'
loadSetting '.tap.developer.registry.project' 'REGISTRY_PROJECT'
loadSetting '.tap.developer.registry.username' 'REGISTRY_USERNAME'
loadSetting '.tap.developer.registry.password' 'REGISTRY_PASSWORD' '-p'

loadSetting '.tds.version' 'TDS_VERSION'
loadSetting '.tds.postgres.version' 'POSTGRES_VERSION'
loadSetting '.tds.mysql.version' 'MYSQL_VERSION'
loadSetting '.tds.rabbitmq.version' 'RABBITMQ_VERSION'

function install_services() {
    kubectx $1

    info "Updating TDS repository on $1."

    tanzu package repository add tanzu-data-services-repository -n tap-install \
        --url $REGISTRY_HOSTNAME/$REGISTRY_PROJECT/tds-packages:$TDS_VERSION \
    
    info "Updating RabbitMQ repository on $1."

    tanzu package repository add tanzu-rabbitmq-repository -n tap-install \
        --url $ESSENTIALS_REGISTRY_HOSTNAME/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo:$RABBITMQ_VERSION \

    info "Exporting registry secret to all namespaces."

    tanzu secret registry update registry-credentials -n $DEVELOPER_NAMESPACE --export-to-all-namespaces --yes

    info "Installing Postgres Operator $POSTGRES_VERSION."

    tanzu package install postgres-operator -n tap-install \
        --package-name postgres-operator.sql.tanzu.vmware.com \
        --version $POSTGRES_VERSION \
        -f $VALUES_DIR/run/postgres.yaml

    success "Postgres Operator $POSTGRES_VERSION successfully installed."

    info "Installing MySQL Operator $MYSQL_VERSION."

    tanzu package install mysql-operator -n tap-install \
        --package-name mysql-operator.with.sql.tanzu.vmware.com \
        --version $MYSQL_VERSION \
        -f $VALUES_DIR/run/mysql.yaml

    success "MySQL Operator $MYSQL_VERSION successfully installed."

    info "Installing RabbitMQ Operator $RABBITMQ_VERSION."

    tanzu package install rabbitmq-operator -n tap-install \
        --package-name rabbitmq.tanzu.vmware.com \
        --version $RABBITMQ_VERSION \
        --service-account-name tap-install-sa

    success "RabbitMQ Operator $MYSQL_VERSION successfully installed."

    kapp deploy --app data-services -n tap-install \
        --file $VALUES_DIR/run/data-services.yaml \
        --yes
}

loginToRunCluster

info "Installing services on $KUBECTX_RUN_CLUSTER."
install_services $KUBECTX_RUN_CLUSTER

success "All services were installed successfully on $KUBECTX_RUN_CLUSTER."
