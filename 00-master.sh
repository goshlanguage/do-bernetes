#!/usr/bin/bash
set -o nounset -o errexit

kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${MASTER_PRIVATE_IP} --apiserver-cert-extra-sans=${MASTER_PUBLIC_IP}
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.0/Documentation/kube-flannel.yml
systemctl enable docker kubelet

# used to join nodes to the cluster
kubeadm token create --print-join-command > /tmp/kubeadm_join

# used to setup kubectl
chown core /etc/kubernetes/admin.conf

# setup DigitalOcean token secret for cloud-controller-manager and container-storage-interface
# This should be refactored to use a terraform provisioner most likely.
cat > /tmp/secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "${DO_TOKEN}"
EOF

# deploy kubernetes digitalocean secret for CCM and CSI
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/secret.yaml

# remove sensitive data
rm -vf /tmp/secret.yaml

# setup the DigitalOcean cloud controller manager to manage loadbalancers and more
echo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/${CCM_VERSION}.yml
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/${CCM_VERSION}.yml

# setup the DigitalOcean container storage interface for kubernetes to manage it's own disks through PV and PVCs
echo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/digitalocean/csi-digitalocean/blob/master/deploy/kubernetes/releases/csi-digitalocean-${CSI_VERSION}.yml
# kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/digitalocean/csi-digitalocean/blob/master/deploy/kubernetes/releases/csi-digitalocean-${CSI_VERSION}.yml
