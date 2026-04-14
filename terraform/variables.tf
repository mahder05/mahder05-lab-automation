variable "nginx_node_port" {
  description = "NodePort for the Nginx service"
  type        = number
  default     = 30007
}

variable "namespace_name" {
  description = "The namespace for our production-ready lab"
  type        = string
  default     = "production-ready-lab"
}

variable "awx_password" { type = string }
variable "vault_role_id" { type = string }
variable "vault_secret_id" { type = string }