# Terraform Configuration for E-Commerce CI/CD
# Single Jenkins EC2 + EKS Cluster
# Region: us-west-2

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

