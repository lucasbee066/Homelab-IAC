terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

############################
# Lookup an AMI (Ubuntu 22.04 LTS)
############################
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################
# KMS key for Vault auto-unseal
############################
resource "aws_kms_key" "vault_unseal" {
  description             = "Vault auto-unseal key"
  deletion_window_in_days = 7
  enable_key_rotation     = false
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

############################
# IAM Role/Instance Profile for EC2
############################
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "vault_ec2_role" {
  name               = "${var.name_prefix}-vault-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.vault_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "vault_kms_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey"
    ]
    resources = [aws_kms_key.vault_unseal.arn]
  }
}

resource "aws_iam_role_policy" "vault_kms" {
  name   = "${var.name_prefix}-vault-kms"
  role   = aws_iam_role.vault_ec2_role.id
  policy = data.aws_iam_policy_document.vault_kms_policy.json
}

resource "aws_iam_instance_profile" "vault_profile" {
  name = "${var.name_prefix}-vault-profile"
  role = aws_iam_role.vault_ec2_role.name
}

############################
# Security Group (SSH + Vault)
############################
resource "aws_security_group" "vault_sg" {
  name        = "${var.name_prefix}-vault-sg"
  description = "Allow SSH and Vault API"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Vault API (recommend restrict later)"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.allowed_vault_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-vault-sg"
  }
}

############################
# EC2 Instance
############################
resource "aws_instance" "vault" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.small"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]
  associate_public_ip_address = var.associate_public_ip

  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.vault_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name = "${var.name_prefix}-vault"
  }
}
