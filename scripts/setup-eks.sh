#!/bin/bash
set -e

echo "=== AWS EKS Cluster Setup ==="
echo "This script creates an EKS cluster with Multi-AZ VPC"

# Variables
CLUSTER_NAME="ecommerce-cluster"
REGION="us-east-1"
NODE_TYPE="t3.medium"
MIN_NODES=3
MAX_NODES=10
DESIRED_NODES=3

# Create EKS cluster using eksctl
echo "Creating EKS cluster: ${CLUSTER_NAME}..."

eksctl create cluster \
  --name ${CLUSTER_NAME} \
  --region ${REGION} \
  --node-type ${NODE_TYPE} \
  --nodes-min ${MIN_NODES} \
  --nodes-max ${MAX_NODES} \
  --nodes ${DESIRED_NODES} \
  --managed \
  --asg-access \
  --external-dns-access \
  --full-ecr-access \
  --appmesh-access \
  --alb-ingress-access \
  --node-private-networking \
  --vpc-private-subnets subnet-xxx,subnet-yyy,subnet-zzz \
  --vpc-public-subnets subnet-aaa,subnet-bbb,subnet-ccc

echo "=== EKS Cluster Created Successfully ==="
echo "Run 'aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}' to configure kubectl"
