# EKS Cluster and Node Group

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# EKS Node Group for Applications (Public Subnets - Frontend/Backend)
resource "aws_eks_node_group" "app_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "ecommerce-app-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  instance_types = ["c7i-flex.large"]

  # Labels for node selection
  labels = {
    workload-type = "application"
    environment   = "production"
  }

  remote_access {
    ec2_ssh_key               = var.key_name
    source_security_group_ids = [aws_security_group.eks_node_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly_policy
  ]
}

# EKS Node Group for Database (Private Subnets - PostgreSQL)
resource "aws_eks_node_group" "db_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "ecommerce-db-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  instance_types = ["c7i-flex.large"]

  # Labels for node selection
  labels = {
    workload-type = "database"
    environment   = "production"
  }

  # Taints to prevent app pods from scheduling on DB nodes
  taint {
    key    = "dedicated"
    value  = "database"
    effect = "NO_SCHEDULE"
  }

  remote_access {
    ec2_ssh_key               = var.key_name
    source_security_group_ids = [aws_security_group.eks_node_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly_policy
  ]
}
