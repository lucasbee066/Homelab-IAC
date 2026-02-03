
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "name_prefix" {
  type    = string
  default = "lab"
}

# Existing network (your VPC)
variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

# Your existing AWS key pair name
variable "key_name" {
  type        = string
  description = "Existing AWS EC2 Key Pair name"
}

# Lock these down to your home IP (or VPN) as you refine
variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH (e.g. your public IP /32)"
}

variable "allowed_vault_cidr" {
  type        = string
  description = "CIDR allowed to access Vault API (8200)"
}

variable "associate_public_ip" {
  type    = bool
  default = true
}
