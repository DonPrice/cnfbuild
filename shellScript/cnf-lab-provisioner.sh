#!/usr/bin/bash

APT_PACKAGES="net-tools"
for package in ${APT_PACKAGES} ; do
    sudo apt install ${package}
done

SNAP_PACKAGES="helm kubectl yq"
for snaps in ${SNAP_PACKAGES} ; do
    sudo snap install ${snaps} --classic
done

mkdir -p .kube
cp ~/build/k3sKubeConfig/10.1.1.6/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/https:\/\/127.0.0.1:6443/https:\/\/10.1.1.6:6443/g' ~/.kube/config