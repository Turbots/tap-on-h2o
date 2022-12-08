#!/bin/zsh

source 00-functions.sh

loginToSupervisor $KUBECTX_SV_CLUSTER
loginToViewCluster
loginToBuildCluster
loginToRunCluster

success "Logged in to all clusters!"