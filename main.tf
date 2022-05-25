terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "dev-cpoc-coolsox-iks-1"
    }
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

### Remote State - Import Kube Config ###
data "terraform_remote_state" "iks-1" {
  backend = "remote"

  config = {
    organization = "mel-ciscolabs-com"
    workspaces = {
      name = "iks-cpoc-syd-demo-1"
    }
  }
}

### Decode Kube Config ###
# Assumes kube_config is passed as b64 encoded
locals {
  kube_config = yamldecode(base64decode(data.terraform_remote_state.iks-1.outputs.kube_config))
}

### Providers ###
provider "kubernetes" {
  # alias = "iks-k8s"
  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

module "coolsox" {
  source = "github.com/cisco-apjc-cloud-se/terraform-helm-coolsox"
  smm_enabled = true
  panoptica_enabled = true

  appd = {
    application = {
      name = "coolsox-rw"
    }
    account = {
      host          = format("%s.saas.appdynamics.com", var.appd_account_name)
      name          = var.appd_account_name       # Passed from Workspace Variable
      key           = var.appd_account_key        # Passed from Workspace Variable
      otel_api_key  = var.appd_otel_api_key       # Passed from Workspace Variable
      username      = var.appd_account_username   # Passed from Workspace Variable
      password      = var.appd_account_password   # Passed from Workspace Variable
    }
    db_agent = {
      enabled     = true
      name        = "coolsox-dbagent"
      databases   = {
        mongodb = {
          name = "mongodb"
          user = "appdagent"
          password = var.appd_account_password
        }
      }
    }
  }

  helm = {
    namespace     = "coolsox"
    release_name  = "coolsox"
    repository    = "https://github.com/cisco-apjc-cloud-se/app-fso-coolsox/raw/main/application/helm/"
    chart         = "coolsox"
    version       = "0.2.0" # In Helm Chart!
  }

  settings = {
    kubernetes = {
      repository                = "public.ecr.aws/j8r8c0y6/coolsox"
      image_pull_policy         = "Always"
      read_only_root_filesystem = false # breaks AppD Java Agents?
    }
    carts = {
      version   = "1.0.0"
      replicas  = 1
    }
    catalogue_db = {
      version   = "1.0.0"
    }
    catalogue = {
      version       = "1.0.0"
      replicas      = 1
      appd_tiername = "catalogue"
    }
    frontend = {
      version                  = "1.0.0"
      replicas                 = 1
      appd_browser_rum_enabled = false
      ingress = {
        enabled = true
        url = "fso-demo-app.cisco.com"
      }
      loadbalancer = {
        enabled = false
      }
    }
    orders = {
      version   = "1.0.0"
      replicas  = 1
    }
    payment = {
      version       = "1.0.0"
      replicas      = 1
      appd_tiername = "payment"
    }
    queue = {
      version   = "1.0.0"
    }
    shipping = {
      version   = "1.0.0"
      replicas  = 1
    }
    user_db = {
      version   = "1.0.0"
    }
    user = {
      version       = "1.0.0"
      replicas      = 1
      appd_tiername = "user"
    }
    load_test = {
      enabled       = true
      version       = "1.0.0"
      replicas      = 1
    }
  }

}
