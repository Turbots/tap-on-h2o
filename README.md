# tap-on-h2o

Automates TAP installation on H2o environments

## Instructions

- For best user experience, run this using [VScode Remote container plugin](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack). This will ensure all dependencies, are met.

### Preparation

- Rename the `values/default.yaml.template` file to `values/default.yaml` and fill in all the necessary values
- Make sure the corresponding cluster information is available in the `clusters` folder, eg. `clusters/tools/tap-view-cluster.yaml`
- Make sure the corresponding vSphere namespaces are created in your H2o environment and have the necessary users, storage policies, and VM classes assigned

### Installation

- Provision the clusters using the `01-create-clusters.sh` script
- Install the Tanzu Cluster Essentials bundle using the `02-install-cluster-essentials.sh` script
- Install the view profile using the `03-install-view-profile.sh` script
- Install the build profile using the `04-install-build-profile.sh` script
- Install the run profile using the `05-install-run-profile.sh` script
- Update the view cluster with service account tokens and metadata store Bearer Token by running the `06-update-view-cluster.sh` script
- (optional) Install all necessary data services like Postgres, MySQL and RabbitMQ on the run cluster by running the `07-install-services.sh` script

### Testing

- Apply new workloads to the build cluster
- Deploy workloads to the run cluster
