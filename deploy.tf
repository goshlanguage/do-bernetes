# do_token is your DigitalOcean API token
variable "do_token" {}

variable "do_region" {
    default = "nyc3"
}

# See README.md for more information
variable "ssh_fingerprint" {}
variable "ssh_private_key" {
    default = "~/.ssh/id_rsa"
}

variable "number_of_workers" {
	default = "1"
}

# Find current versions of k8s images at
# https://console.cloud.google.com/gcr/images/google-containers/GLOBAL
# or specifically
# https://console.cloud.google.com/gcr/images/google-containers/GLOBAL/kube-apiserver-amd64?gcrImageListsize=30
#
# Known working versions:
# v1.10.3
variable "k8s_version" {
	default = "v1.13.2"
}

# When changing the k8s_version, it is important to also update CCM and CSI versions.
# https://github.com/digitalocean/digitalocean-cloud-controller-manager/blob/master/docs/getting-started.md#version
variable "ccm_version" {
    default = "v0.1.8"
}

# https://github.com/digitalocean/csi-digitalocean#kubernetes-compatibility
variable "csi_version" {
    default = "v1.0.0"
}

# https://github.com/containernetworking/cni/releases
variable "cni_version" {
	default = "v0.6.0"
}

variable "size_master" {
    default = "2gb"
}

variable "size_worker" {
    default = "2gb"
}


# PROVIDER #
provider "digitalocean" {
    token = "${var.do_token}"
}


# Setup the master kubernetes nodes
resource "digitalocean_droplet" "k8s-master" {
    image = "coreos-stable"
    name = "k8s-master"
    region = "${var.do_region}"
    private_networking = true
    size = "${var.size_master}"
    ssh_keys = ["${split(",", var.ssh_fingerprint)}"]

    provisioner "file" {
        source = "./00-master.sh"
        destination = "/tmp/00-master.sh"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    provisioner "file" {
        source = "./install-kubeadm.sh"
        destination = "/tmp/install-kubeadm.sh"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # Install dependencies and set up cluster
    provisioner "remote-exec" {
        inline = [
            "export DO_TOKEN=\"${var.do_token}\"",
            "export K8S_VERSION=\"${var.k8s_version}\"",
            "export CCM_VERSION=\"${var.ccm_version}\"",
            "export CSI_VERSION=\"${var.csi_version}\"",
            "export CNI_VERSION=\"${var.cni_version}\"",

            "chmod +x /tmp/install-kubeadm.sh",
            "sudo -E /tmp/install-kubeadm.sh",
            "export MASTER_PRIVATE_IP=\"${self.ipv4_address_private}\"",
            "export MASTER_PUBLIC_IP=\"${self.ipv4_address}\"",
            "chmod +x /tmp/00-master.sh",
            "sudo -E /tmp/00-master.sh"
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # copy secrets to local
    provisioner "local-exec" {
        command =<<EOF
            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key} core@${digitalocean_droplet.k8s-master.ipv4_address}:"/tmp/kubeadm_join /etc/kubernetes/admin.conf" ${path.module}/secrets
            cp "${path.module}/secrets/admin.conf" "${path.module}/secrets/admin.conf.bak"
            sed -e "s/${self.ipv4_address_private}/${self.ipv4_address}/" "${path.module}/secrets/admin.conf.bak" > "${path.module}/secrets/admin.conf"
EOF
    }

    # deploy kubernetes digitalocean secret for CCM and CSI
    provisioner "local-exec" {
        command=<<EOF
            kubectl --kubeconfig=${path.module}/secrets/admin.conf apply -f ${path.module}/secrets/do-token.yaml
EOF
    }
}

# Setup worker pool
resource "digitalocean_droplet" "k8s-worker" {
    count = "${var.number_of_workers}"
    image = "coreos-stable"
    name = "${format("k8s-worker-%02d", count.index + 1)}"
    region = "${var.do_region}"
    size = "${var.size_worker}"
    private_networking = true
    # user_data = "${data.template_file.worker_yaml.rendered}"
    ssh_keys = ["${split(",", var.ssh_fingerprint)}"]
    depends_on = ["digitalocean_droplet.k8s-master"]

    # Start kubelet
    provisioner "file" {
        source = "./01-worker.sh"
        destination = "/tmp/01-worker.sh"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    provisioner "file" {
        source = "./install-kubeadm.sh"
        destination = "/tmp/install-kubeadm.sh"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    provisioner "file" {
        source = "./secrets/kubeadm_join"
        destination = "/tmp/kubeadm_join"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # Install dependencies and join cluster
    provisioner "remote-exec" {
        inline = [
            "export K8S_VERSION=\"${var.k8s_version}\"",
            "export CNI_VERSION=\"${var.cni_version}\"",
            "chmod +x /tmp/install-kubeadm.sh",
            "sudo -E /tmp/install-kubeadm.sh",
            "export NODE_PRIVATE_IP=\"${self.ipv4_address_private}\"",
            "chmod +x /tmp/01-worker.sh",
            "sudo -E /tmp/01-worker.sh"
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    provisioner "local-exec" {
        when = "destroy"
        command = <<EOF
export KUBECONFIG=${path.module}/secrets/admin.conf
kubectl drain --delete-local-data --force --ignore-daemonsets ${self.name}
kubectl delete nodes/${self.name}
EOF
    }
}
