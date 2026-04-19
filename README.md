# 🚀 DevOps Mastery Lab

A local, production-grade DevOps environment powered by Kubernetes (k3s) and Colima, featuring a fully integrated CI/CD and Secrets Management stack. This repository contains the Infrastructure-as-Code (IaC) and automation scripts to deploy a complete DevOps ecosystem locally. It leverages Colima for the container runtime and k3d for a lightweight Kubernetes distribution.

![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s-blue?logo=kubernetes)
![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?logo=terraform)
![Ansible](https://img.shields.io/badge/Automation-AWX-red?logo=ansible)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo)
![Vault](https://img.shields.io/badge/Security-Vault-black?logo=vault)
![Grafana](https://img.shields.io/badge/Observability-Grafana-F46800?logo=grafana)

## 🏗️ Architecture Overview

This lab simulates a real-world enterprise environment on a local machine, utilizing a modular GitOps architecture to prevent resource conflicts.

| Component                   | Tool / Technology        | Purpose                                      |
|-----------------------------|--------------------------|----------------------------------------------|
| Container Runtime           | Colima (macOS/Linux)     | Linux VM for macOS/Docker compatibility      |
| Orchestration               | k3s (via k3d)            | High-performance local Kubernetes cluster    |   
| Infrastructure as Code      | Terraform                | Automated provisioning of K8s resources      |
| Ingress Controller          | Traefik                  | Native K3s load balancer                     |
| Continuous Delivery/GitOps  | ArgoCD                   | Declarative CD (Modular App-of-Apps)         |
| Automation/Configuration    | AWX (Ansible)            | Ansible-based configuration management       |
| Secrets Management/Security | HashiCorp Vault          | Centralized secrets management               |     
| Observability               | Grafana                  | Visualization of cluster metrics             |

## 🛠️ Tech Stack & Ports

| Service  | Access URL                | Purpose                            |                    
|----------|---------------------------|------------------------------------|
| ArgoCD   | http://argocd.local:8043  | GitOps & App Deployment            |
| AWX      | http://awx.local:8043     | Ansible Automation Engine          |
| Vault    | http://vault.local:8043   | Secrets & Identity Management      |
| Grafana  | http://grafana.local:8043 | Observability & Metrics            |

## 📂 Project Structure

The GitOps structure is deliberately separated to isolate workloads and prevent ArgoCD `SharedResourceWarning` conflicts:

```text
├── terraform/                       # Infrastructure as Code (Bootstraps Cluster & ArgoCD)
├── kubernetes/manifests/            # General lab manifests (Guestbook, Ingresses)
├── argocd/awx-monitoring-stack/     # Isolated AWX & Monitoring stack manifests
├── ansible/                         # AWX playbooks, EE, Vars, Inventory, Collections
└── scripts/                         # Start/Stop/Status automation# 🚀 DevOps Mastery Lab
```


## 🚀 Installation & Deployment Steps.

**Prerequisites**

    - Homebrew
    - Colima
    - k3d
    - kubectl
    - Helm
    - Terraform


**Step 1: Prepare the Engine (Colima)**
      
   Colima provides the Docker/Kubernetes runtime.

    colima start --cpu 4 --memory 8 --disk 100
    
**Step 2: Provision the Cluster (k3d & Terraform)**
   
   Create the cluster and use Terraform to deploy the core services:

    # Create the cluster
    k3d cluster create devops-lab --agents 2 -p "8043:80@loadbalancer"

**Step 3: Provision Infrastructure (Terraform)**
   
   <ins>_Configuration Files Reference_</ins>

   provider.tf - Configures the Kubernetes and Helm providers to point to your k3d-devops-lab context.
   
   main.tf -  Defines the kubernetes_namespace resources and helm_release blocks for
    
    ArgoCD: argo-cd chart in argocd namespace
    Vault: vault chart in awx-mastery namespace.
    AWX Operator: awx-operator chart.
    Monitoring: kube-prometheus-stack chart.

   variables.tf & terraform.tfvars - used to manage cluster naming, toggling services on/off, and defining the list of namespaces to be created.

   Initialize and deploy the base namespaces (argocd, awx-mastery) and Helm charts.

   _Note: This step also bootstraps two independent ArgoCD applications (devops-lab-stack and awx-monitoring-stack) pointing to their respective, isolated Git directories to        prevent resource conflicts._

    cd terraform/
    terraform init
    terraform apply -auto-approve

**Step 4: Validate the GitOps Flow (Optional but Recommended)**

  To ensure ArgoCD is successfully reconciling your cluster state with your Git repository, verify the "Guestbook" test application:

  Ensure your local /etc/hosts file routes guestbook.local to 127.0.0.1.

  Open your browser to http://guestbook.local:8081 (or your mapped load balancer port).

  You should see the standard "Welcome to nginx!" page, confirming your GitOps pipeline is fully operational.

**Step 5: Deploy AWX Instance**
   
   The Terraform script installs the AWX Operator.

   Now, you must deploy the actual AWX instance using a Kubernetes Custom Resource:
   
    cat <<EOF | kubectl apply -f -
    apiVersion: awx.ansible.com/v1beta1
    kind: AWX
    metadata:
      name: awx-dev
      namespace: awx-mastery
    spec:
      service_type: clusterip
      postgres_storage_class: local-path
    EOF
    
   Wait for the pods to reach Running state:

    kubectl get pods -n awx-mastery -w 
    
**Step 5: Initialize & Unseal Vault**

   Since we are using a persistent Vault setup (not dev mode), you must initialize it manually the first time:Bash# Initialize Vault and save the keys!

    kubectl exec -it vault-0 -n awx-mastery -- vault operator init

    # Unseal using 3 of your generated keys
    kubectl exec -it vault-0 -n awx-mastery -- vault operator unseal <KEY_1>
    kubectl exec -it vault-0 -n awx-mastery -- vault operator unseal <KEY_2>
    kubectl exec -it vault-0 -n awx-mastery -- vault operator unseal <KEY_3>
    
**Step 6: Configure Secrets Engine (Vault)**
  
   Once unsealed, log in and enable the Key-Value store:
   
    # Login with Root Token
    kubectl exec -it vault-0 -n awx-mastery -- vault login <ROOT_TOKEN>

    # Enable KV2 engine**
    kubectl exec -it vault-0 -n awx-mastery -- vault secrets enable -path=secret kv-v2
    
**Step 7: Accessing the Web UIs**

   Run the start script to establish all port-forwarding tunnels:

    ./devops_lab_start.sh
    
 🔑 Default Credentials

| Tool    | Credentials |
|---------|-------------|
| ArgoCD  | User: `admin` <br> Pass: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"` |
| AWX     | User: `admin` <br> Pass: `kubectl get secret awx-lab-admin-password -n awx-mastery -o jsonpath="{.data.password}"` |
| Vault   | Use the Root Token generated during initialization |
| Grafana | User: `admin` <br> Pass: `<Your-Password>` (default) |


   **Continuous Delivery (ArgoCD)**
   
   ArgoCD manages the state of the applications inside the cluster.

    Access: https://argocd-local:8043
    Default Login: admin
      
   **Automation (AWX)**
   
   AWX is deployed via the AWX Operator and handles Ansible playbooks.

    Access: http://awx-local:8043
    Default Login: admin

   **Integration**

   Connected to Vault via AppRole for secure credential injection.

   **Observability (Grafana)**

   The monitoring stack collects metrics via Prometheus.

    Access: http://grafana-local:8043 (via port-forward)
    Default Login: admin / admin
   
**Step 8: Environment Management**
   
   Use the provided scripts in the /scripts directory to manage your lab lifecycle:

   Check Status: Validate K8s availability, port-forwarding tunnels, and API responsiveness.
         
    ./devops_lab_status.sh
         
   Stop Lab: Safely spin down the environment to save system resources.

    ./devops_lab_stop.sh

   Restart Lab: Spin the environment back up. (Note: Vault is configured for manual unseal; devops_lab_start.sh handles this automatically if your shards are configured).

    ./devops_lab_start.sh


### 🔍 Optimization: What to check next?
Now that the integration is working, you can perform a **"Zero-Trust" test** in AWX:

1.  **Create a Secret in Vault:**
    ```bash
    kubectl exec -it vault-0 -n awx-mastery -- vault kv put secret/awx/test_creds username="devops_user" password="supersecretpassword"
    ```
2.  **Sync in AWX:** Create a "Credential" in AWX of type **HashiCorp Vault Secret Lookup**.
3.  **Run a Playbook:** Run a simple debug playbook that prints a variable mapped to that Vault secret. If the playbook shows the value (obfuscated as `VALUE_SPECIFIED`), your integration is 100% verified.



### 💡 Troubleshooting Tip
If you ever see a `403 Forbidden` in the AWX job logs while it tries to pull from Vault, check the **Vault Policy** assigned to the AppRole/ServiceAccount. It must have `read` and `list` capabilities for the specific path `secret/data/awx/*`.
         

_<ins>Security Note</ins>_

   This lab uses a Root Token for initial Vault setup and an AppRole for AWX integration. In a production environment, Root Tokens should be revoked immediately after creating      administrative policies.

💡 _Troubleshooting Tip_
   
   If terraform apply fails because the cluster isn't ready, ensure Colima is running with enough resources:

    colima start --cpu 4 --memory 8

💡 _Pro-Tips for the Lab:_ 

  Persistence: Ensure your AWX and Vault instances are backed by Persistent Volume Claims (PVCs) if you want data to survive a k3d cluster stop.
 
  Shell Aliases: Add alias k='kubectl' to your .zshrc or .bashrc for faster navigation.
  

👨‍💻 Author

**Maheshbabu Derangula**
