# Terraform Variables File
# Update these values with your actual configuration

aws_region = "us-west-2"

vpc_id = "vpc-06bec4472137da9cb"

# Public subnets for Frontend/Backend (must have internet gateway route)
subnet_ids = [
  "subnet-05afe4a2c8fa465dd", # us-west-2a public
  "subnet-0e0ae11cab0d4a25d"  # us-west-2b public
]

# Private subnets for PostgreSQL (must have NAT gateway for outbound)
private_subnet_ids = [
  "subnet-084e53ce4bea19402", # us-west-2a private
  "subnet-0607c4649ed0a577a", # us-west-2b private
]

key_name = "tata-key"

jenkins_instance_type = "m7i-flex.large"

allowed_ssh_cidr = "49.47.216.217/32" # Change to your IP

cluster_name = "ecommerce-cluster"

cluster_version = "1.34"
