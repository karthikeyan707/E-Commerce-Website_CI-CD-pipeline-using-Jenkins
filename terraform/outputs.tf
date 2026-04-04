# Outputs for E-Commerce CI/CD Infrastructure

output "jenkins_public_ip" {
  description = "Public IP of Jenkins Server"
  value       = aws_eip.jenkins_eip.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_eip.jenkins_eip.public_ip}:8080"
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.eks.name
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.eks.name}"
}
