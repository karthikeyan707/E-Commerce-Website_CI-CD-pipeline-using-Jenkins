# AWS Load Balancer Controller - Terraform Configuration
# Provides ALB for Ingress with path-based routing

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Use existing IAM Policy for ALB Controller
data "aws_iam_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerIAMPolicy"
}

# IAM Role for ALB Controller (IRSA)
resource "aws_iam_role" "alb_controller_role" {
  name = "${var.cluster_name}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = data.aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller_role.name
}

# Kubernetes Service Account for ALB Controller
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller,
    aws_eks_node_group.app_nodes
  ]
}

# Install AWS Load Balancer Controller via Helm
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    kubernetes_service_account.alb_controller,
    aws_iam_role_policy_attachment.alb_controller
  ]
}

# Output ALB Controller status
output "alb_controller_status" {
  description = "AWS Load Balancer Controller installation status"
  value       = "Installed via Helm in kube-system namespace"
}

output "alb_controller_iam_role" {
  description = "IAM role ARN for ALB Controller"
  value       = aws_iam_role.alb_controller_role.arn
}
