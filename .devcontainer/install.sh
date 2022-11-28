
#mkdir /home/vscode/.kube
#cp .kube/config /home/vscode/.kube/config
#cd tap13
#mkdir $HOME/tanzu
#tar -xvf tanzu-framework-linux-amd64.tar -C $HOME/tanzu
#export TANZU_CLI_NO_INIT=true
#cd $HOME/tanzu
#export VERSION=v0.25.0
#sudo install cli/core/$VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu
#tanzu version
#cd $HOME/tanzu
#tanzu plugin install --local cli all
#tanzu plugin list
#echo alias k=kubectl >> /home/vscode/.bashrc
echo "Post install script finished!!!"