do-bernetes
===
![dobernetes](https://img.shields.io/badge/do-bernetes-3371e3.svg?longCache=true)

Deploy a Kubernetes cluster to Digital Ocean simply enough to learn about it in the process.

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

You will also need an SSH key uploaded to DigitalOcean.
[]()

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

## DigitalOcean controller manager and container storage interface ##
After you plan and apply, you'll want to first create and deploy a kubernetes secret to give your cloud controller access to the DigitalOcean api on your behalf.
To do that, create a file, say `secret.yaml`, replacing the following dummy API key with your own:

`secret.yaml`:
```
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "a05dd2f26b9b9ac2asdas__REPLACE_ME____123cb5d1ec17513e06da"
```

After you've created this manifest, we can create it on your kubernetes cluster by running:
```
kubectl create -f secret.yaml
```

With this, we can launch the cloud controller manager to let kubernetes orchestrate things through the DigitalOcean API. To do so, we need to consult the cloud controller manager docs to make sure we launch the right one. Compatibility here is no joke. Check out (https://github.com/digitalocean/digitalocean-cloud-controller-manager/blob/master/docs/getting-started.md#version) to make sure you use the right version.
```
kubectl apply -f https://raw.githubusercontent.com/digitalocean/digitalocean-cloud-controller-manager/master/releases/v0.1.5.yml
```

We also need to setup the Container storage interface (CSI) that allows Kubernetes to provision disks through the API. This software also has tight coupling on version. To ensure for compatibility, see first: (https://github.com/digitalocean/csi-digitalocean#kubernetes-compatibility). DigitalOcean's CSI can deployed by running:
```
kubectl apply -f https://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v0.2.0.yaml
```


Finally, access your cluster by exporting the `KUBECONFIG` variable. While in this project's top level directory, run:
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
NAME            STATUS     ROLES    AGE    VERSION
k8s-master      NotReady   master   109s   v1.13.2
k8s-worker-01   NotReady   <none>   19s    v1.13.2
```