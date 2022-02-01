############################################################################################
# Copyright 2020 Palo Alto Networks.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
############################################################################################

terraform {
  required_version = ">= 0.12"
}

provider helm {
  kubernetes {
  config_path = "~/.kube/config"
  }
}

# data resource to allow for obtaining the public ip of the panorama instance
data "google_compute_instance" "panorama" {
  name = "panorama"
  zone = "us-central1-a"
}

resource "helm_release" "cn-series" {
  name       = "cn-series-deploy"
  repository = "https://paloaltonetworks.github.io/cn-series-hackathon-helm/"
  chart      = "cn-series"
  version    = "0.1.5"
  timeout    = 600
  wait       = false

  // Kubernetes values
  set {
    name  = "cluster.deployTo"
    value = var.k8s_environment
    type  = "string"
  }

  // Panorma values
  set {
    name  = "panorama.ip"
    value = data.google_compute_instance.panorama.network_interface.0.access_config.0.nat_ip
    type  = "string"
  }

  set {
    name  = "panorama.ip2"
    value = var.panorama_ip2
    type  = "string"
  }

  set {
    name  = "panorama.authKey"
    value = var.panorama_auth_key
    type  = "string"
  }

  set {
    name  = "panorama.deviceGroup"
    value = var.panorama_device_group
    type  = "string"
  }

  set {
    name  = "panorama.template"
    value = var.panorama_template_stack
    type  = "string"
  }

  set {
    name  = "panorama.cgName"
    value = var.panorama_collector_group
    type  = "string"
  }

  // CNI values
  set {
    name  = "cni.image"
    value = var.k8s_cni_image
    type  = "string"
  }

  set {
    name  = "cni.version"
    value = var.k8s_cni_version
    type  = "string"
  }

  // MP values
  set {
    name  = "mp.initImage"
    value = var.k8s_mp_init_image
    type  = "string"
  }

  set {
    name  = "mp.initVersion"
    value = var.k8s_mp_init_version
    type  = "string"
  }

  set {
    name  = "mp.image"
    value = var.k8s_mp_image
    type  = "string"
  }

  set {
    name  = "mp.version"
    value = var.k8s_mp_image_version
    type  = "string"
  }

  set {
    name  = "mp.cpuLimit"
    value = var.k8s_mp_cpu
  }

  // DP values
  set {
    name  = "dp.image"
    value = var.k8s_dp_image
    type  = "string"
  }

  set {
    name  = "dp.version"
    value = var.k8s_dp_image_version
    type  = "string"
  }

  set {
    name  = "dp.cpuLimit"
    value = var.k8s_dp_cpu
    type  = "string"
  }


  // Firewall values
  set {
    name  = "firewall.failoverMode"
    value = "failopen"
    type  = "string"
  }

  set {
    name  = "firewall.operationMode"
    value = "daemonset"
    type  = "string"
  }

  set {
    name  = "firewall.serviceName"
    value = "pan-mgmt-svc"
    type  = "string"
  }

  // Service account values
  set {
    name  = "serviceAccount.create"
    value = "true"
    type  = "string"
  }

  set {
    name  = "serviceAccount.name"
    value = "pan-plugin-user"
    type  = "string"
  }
}

# generate the k8s secret file and initiate download to client
resource "null_resource" "obtain_k8s_secret_file" {
  triggers = {
    time_stamp = timestamp()
  }

  provisioner "local-exec" {
    command = "kubectl get secret `kubectl get serviceaccounts pan-plugin-user -n kube-system -o jsonpath='{.secrets[0].name}'` -n kube-system -o json > pan-plugin-user.json && cloudshell download-files pan-plugin-user.json"
  }

  depends_on = [helm_release.cn-series]
}
