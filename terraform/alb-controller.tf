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

# Output: Manual installation instructions
output "alb_controller_iam_role" {
  description = "IAM role ARN for ALB Controller (use this when installing via Helm)"
  value       = aws_iam_role.alb_controller_role.arn
}

output "alb_controller_install_command" {
  description = "Command to install ALB Controller manually on EC2"
  value       = <<-EOT
    # SSH to EC2 and run:
    aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
    
    # Create service account with IAM role
    kubectl create serviceaccount aws-load-balancer-controller -n kube-system
    kubectl annotate serviceaccount aws-load-balancer-controller \
      -n kube-system \
      eks.amazonaws.com/role-arn=${aws_iam_role.alb_controller_role.arn}
    
    # Install ALB Controller via Helm
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=${var.cluster_name} \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller \
      --set region=${var.aws_region} \
      --set vpcId=${var.vpc_id}
  EOT
}
