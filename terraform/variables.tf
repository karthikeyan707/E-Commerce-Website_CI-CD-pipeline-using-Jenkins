# Variables for E-Commerce CI/CD Infrastructure

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS and Jenkins (public subnets for frontend/backend)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for database workloads (PostgreSQL)"
  type        = list(string)
}

variable "key_name" {
  description = "AWS Key Pair name for SSH access"
  type        = string
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "c7i-flex.large"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ecommerce-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}
