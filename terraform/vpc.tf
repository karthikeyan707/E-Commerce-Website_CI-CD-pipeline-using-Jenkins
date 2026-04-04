# Security Groups for VPC

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name_prefix = "jenkins-sg-"
  description = "Security group for Jenkins Server"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "Jenkins Web UI"
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "Jenkins Web UI"
 }
 
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "Jenkins Web UI"
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "jenkins-sg"
    Environment = "production"
  }
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "eks-cluster-sg-"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

# Security Group for EKS Nodes
resource "aws_security_group" "eks_node_sg" {
  name_prefix = "eks-node-sg-"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow inter-node communication"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
    description     = "Allow cluster API access"
  }

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
    description     = "Allow kubelet access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-node-sg"
  }
}

# Allow Jenkins to access EKS nodes
resource "aws_security_group_rule" "jenkins_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_sg.id
  security_group_id        = aws_security_group.eks_cluster_sg.id
  description              = "Allow Jenkins to access EKS API"
}
