terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12" # Modern version for M4 compatibility
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"  # This matches your current environment better
    }
  }
}

# --- Providers ---

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "vault" {
  address = "http://localhost:8200"
  # Best Practice: Export VAULT_TOKEN in your terminal 
  # instead of hardcoding it here.
}

# --- 1. Kubernetes Namespace ---

resource "kubernetes_namespace" "devops_lab" {
  metadata {
    name = var.namespace_name
  }
}

# --- 2. Nginx Deployment (Pod & Service) ---

resource "kubernetes_pod" "nginx_pod" {
  metadata {
    name      = "terraform-nginx"
    namespace = kubernetes_namespace.devops_lab.metadata[0].name
    labels = {
      app = "nginx"
      env = "learning"
    }
  }

  spec {
    container {
      image = "nginx:latest"
      name  = "nginx-container"
      port {
        container_port = 80
      }
    }
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.devops_lab.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
      env = "learning"
    }

    port {
      port        = 80
      target_port = 80
      node_port   = var.nginx_node_port
    }

    type = "NodePort"
  }
}

# --- 3. AWX Operator (The Management Layer) ---

# --- 3. AWX Operator (The Management Layer) ---

resource "helm_release" "awx_operator" {
  name       = "awx-operator"
  # Use the dedicated -helm repository URL
  repository = "https://ansible-community.github.io/awx-operator-helm/"
  chart      = "awx-operator"
  namespace  = kubernetes_namespace.devops_lab.metadata[0].name

  # Optional: Use a specific stable version (e.g., 3.2.1 as of April 2026)
  # version    = "3.2.1"

  # Ensures the operator doesn't start until the namespace is ready
  depends_on = [kubernetes_namespace.devops_lab]
}

# --- 4. Vault Secret Management ---

resource "vault_generic_secret" "ansible_creds" {
  path = "secret/ansible"

  data_json = jsonencode({
    username = "admin"
    password = "Dkbmlrv@508"
  })
}

# --- Outputs ---

output "final_status" {
  value = <<EOF

  ✅ Infrastructure Applied!
  
  Kubernetes:
  - Namespace: ${kubernetes_namespace.devops_lab.metadata[0].name}
  - Nginx URL: http://$(minikube ip):${var.nginx_node_port}
  
  AWX:
  - Operator Status: Deployed via Helm
  - Next Step: Apply the AWX Custom Resource (YAML) to start the AWX instance.
  
  Vault:
  - Secret Path: ${vault_generic_secret.ansible_creds.path}
  
  EOF
}

# --- 5. The actual AWX Instance ---

resource "kubernetes_manifest" "awx_instance" {
  manifest = {
    apiVersion = "awx.ansible.com/v1beta1"
    kind       = "AWX"
    metadata = {
      name      = "awx-lab"
      # Use the new namespace variable
      namespace = kubernetes_namespace.devops_lab.metadata[0].name 
    }
    spec = {
      service_type     = "NodePort"
      development_mode = true
      
      # ADD THIS: Point to your existing postgres data if you moved it
      postgres_configuration_secret = "postgres-15-awx-lab-postgres-15-0"
    }
  }
  depends_on = [helm_release.awx_operator]
}

# The AWX provider - This allows Terraform to create buttons and settings inside AWX
provider "awx" {
  endpoint = "http://localhost:8080" # Or your minikube IP
  username = "admin"
  password = "Dkbmlrv@508"
}

resource "awx_credential" "vault_approle" {
  name            = "Vault AppRole Credential"
  organization_id = 1
  credential_type = "Hashicorp_Vault_AppRole"

  inputs = jsonencode({
    address   = "http://vault.vault.svc.cluster.local:8200" # Internal K8s address
    role_id   = var.vault_role_id
    secret_id = var.vault_secret_id
  })
}