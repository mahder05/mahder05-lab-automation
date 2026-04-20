# --- Infrastructure: k3d Cluster ---
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["awx-mastery", "argocd", "monitoring"])
  metadata {
    name = each.key
  }
}

resource "shell_script" "k3d_cluster" {
  lifecycle_commands {
    # Match the host port to the container port (80:80)
    create = "k3d cluster create devops-lab --agents 2 -p '80:80@loadbalancer'"
    delete = "k3d cluster delete devops-lab"
  }
}

resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com" # Required to fetch from internet
  chart            = "vault"                               # The name of the chart in the repo
  namespace        = "awx-mastery"
  create_namespace = "true"
}

# --- GitOps: ArgoCD ---
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = "true"

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
}

# --- Monitoring ---
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = "true"

  # Fix the admin password here
  set {
    name  = "grafana.adminPassword"
    value = "Dkbmlrv@508"
  }

  # Ensure data persists across restarts
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "grafana.grafana\\.ini.security.force_password_change"
    value = "false"
  }
}

# --- 1. General Lab Stack (Guestbook, Ingresses, etc.) ---
resource "kubernetes_manifest" "argocd_application_lab" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "devops-lab-stack"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/mahder05/mahder05-devops-iac-setup.git"
        targetRevision = "main"
        path           = "kubernetes/manifests" # Points to the general lab folder
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}

# --- 2. AWX & Monitoring Stack (Independent) ---
resource "kubernetes_manifest" "argocd_application_awx" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "awx-monitoring-stack"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/mahder05/mahder05-devops-iac-setup.git"
        targetRevision = "main"
        path           = "argocd/awx-monitoring-stack" # Points to your new stack folder
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "awx-mastery" # Keeping this in its own namespace is cleaner
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}
