#!/usr/bin/bash
# https://kvz.io/blog/2013/11/21/bash-best-practices/
# set -e for errexit (exit if a command fails)
# set -u for nounset (exit if script tries to use undefined variables)
set -eu

kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${MASTER_PRIVATE_IP} --apiserver-cert-extra-sans=${MASTER_PUBLIC_IP}
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml
systemctl enable docker kubelet

# used to join nodes to the cluster
kubeadm token create --print-join-command > /tmp/kubeadm_join

# used to setup kubectl
chown core /etc/kubernetes/admin.conf

# setup the DigitalOcean token secret to grant access to the cloud controller manager (CCM)
# and the container storage interface (CSI)
cat <<EOF | sudo tee /tmp/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "${DO_TOKEN}"
EOF

# create the kubernetes secret for DigitalOcean
echo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/secret.yaml

# Remove our secret
rm -v /tmp/secret.yaml


# setup the DigitalOcean CCM to manage loadbalancers and more
echo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/${CCM_VERSION}.yml
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/${CCM_VERSION}.yml

# setup the DigitalOcean CSI for kubernetes to manage it's own disks through PV and PVCs
echo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/digitalocean/csi-digitalocean/blob/master/deploy/kubernetes/releases/csi-digitalocean-${CSI_VERSION}.yml
# kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/digitalocean/csi-digitalocean/blob/master/deploy/kubernetes/releases/csi-digitalocean-${CSI_VERSION}.yml
