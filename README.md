do-bernetes
===
![dobernetes](https://img.shields.io/badge/do-bernetes-3371e3.svg?longCache=true)

Deploy a Kubernetes cluster to Digital Ocean simply enough to learn about it in the process.

First of all, all attribution and inspiration for most of this project comes from [kubernetes-digitalocean-terraform](https://github.com/kubernetes-digitalocean-terraform/kubernetes-digitalocean-terraform). This project is simplified for the sake of being an approachable way to experiment with Kubernetes.

# Quick Start

If you are familiar with terraform and DigitalOcean, you can set the following environment variables,
and run plan and apply to get started:

|Environment Variable| Description|
|-|-|
|TF_VAR_do_token|Your digital ocean API token|
|TF_VAR_ssh_fingerprint|$(ssh-keygen -E md5 -lf ~/.ssh/id_rsa.pub | awk '{print $2}' | awk -F"MD5:" '{print $2}')|
|||


In this tutorial, we'll use DigitalOcean's API to help us manage droplets, disks, loadbalancers and more. You can get a DigitalOcean API token at:
[https://cloud.digitalocean.com/settings/tokens/new](https://cloud.digitalocean.com/settings/tokens/new)

Once you have your token setup, you can either paste it into the `do_token` field in `deploy.tf`, or you can export it to an environment variable with:
```
export TF_VAR_do_token=ENTER_YOUR_TOKEN_HERE
```

You will also need an SSH key uploaded to DigitalOcean. A guide for this can be found at [How to Upload SSH Public Keys to a DigitalOcean Account](https://www.digitalocean.com/docs/droplets/how-to/add-ssh-keys/to-account/)


After you've done that, you'll need to find it's MD5 fingerprint, as DigitalOcean uses this to select which SSH key it uses to grant access to your droplets.
To do so, you can run:
```
ssh-keygen -E md5 -lf ~/.ssh/id_rsa.pub | awk '{print $2}' | awk -F"MD5:" '{print $2}'
```

Once you have your SSH key fingerprint, you can export it to an environment variable by executing:
```
export TF_VAR_ssh_fingerprint=ENTER_YOUR_FINGERPRINT_HERE
```

Now, we're ready to run Terraform init, plan, and apply:
```
terraform init
terraform plan -out plan.out
terraform apply "plan.out"
```

This should bring up your Kubernetes cluster on DigitalOcean.

# DigitalOcean controller manager and container storage interface #

What follows is an explanation of how this project deploys the DigitalOcean [cloud controller manager](https://github.com/digitalocean/digitalocean-cloud-controller-manager) (CCM) and [container storage interface](https://raw.githubusercontent.com/digitalocean/csi-digitalocean/) (CSI) are deployed. Skip this if you just want to use Kubernetes or are disinterested in the details.

In order to give the CCM and CSI authorization to do this on your behalf, this project uses the `TF_VAR_do_token` variable you entered before.

It uses this variable to create a kubernetes secret. You can see the manifest in the `secrets/` directory.

`secret.yaml`:
```
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "${TF_VAR_do_token}"
```

After this manifest is created, we deploy it to your kubernetes master by running:
```
kubectl create -f secret.yaml
```

With this access, CCM can provision loadbalancers, disks, and more through the DigitalOcean API.

# Updating Versions #

It is important to consult the cloud controller manager docs when updating to ensure that you use compatible versions of Kubernetes relative to the CCM. Compatibility here is no joke. See (https://github.com/digitalocean/digitalocean-cloud-controller-manager/blob/master/docs/getting-started.md#version) to make sure you use the right version.
```
kubectl apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/v0.1.5.yml
```

We also need to setup CSI that allows Kubernetes to provision disks through the API. This software also has tight coupling on version. To ensure for compatibility, see first: (https://github.com/digitalocean/csi-digitalocean#kubernetes-compatibility). DigitalOcean's CSI can deployed by running:
```
kubectl apply -f https://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v0.2.0.yaml
```

# How to access your cluster
You can access your cluster by setting and exporting the `KUBECONFIG` variable. While in this project's top level directory, run:
```
export KUBECONFIG=$(pwd)/secrets/admin.conf
```

For confirmation, you should be able to now use the kubectl binary to see the status of your nodes:
```
kubectl get nodes
```

Example:
```
kubectl get nodes
NAME            STATUS   ROLES    AGE   VERSION
k8s-master      Ready    master   13m   v1.13.2
k8s-worker-01   Ready    <none>   10m   v1.13.2
```