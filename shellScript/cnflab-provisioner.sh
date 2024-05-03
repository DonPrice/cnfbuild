#!/usr/bin/bash

APT_PACKAGES="net-tools bash-completion"
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

# Setup Kubectl AutoCompletion
kubectl completion bash > ~/.bash_kube_completion

# Kubectl shortcuts
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

echo "alias k='kubectl'" >> ~/.bashrc
echo "alias kgp='kubectl get pods'" >> ~/.bashrc
echo "alias kgs='kubectl get svc'" >> ~/.bashrc
echo "alias kdp='kubectl describe pod'" >> ~/.bashrc
echo "alias kl='kubectl logs -f'" >> ~/.bashrc
echo "alias klf='kubectl logs -f'" >> ~/.bashrc
echo "alias kxb='kubectl exec -it'" >> ~/.bashrc
echo "alias kdesc='kubectl describe'" >> ~/.bashrc
echo "alias kgettmm='kubectl get pods -owide  | grep tmm | sort -k8'" >> ~/.bashrc
echo "alias kgrs='kubectl get rs '" >> ~/.bashrc
echo "alias kdrs='kubectl describe rs '" >> ~/.bashrc
echo "alias kgd='kubectl get deploy '" >> ~/.bashrc

echo 'source ~/.bash_kube_completion'  >> ~/.bashrc