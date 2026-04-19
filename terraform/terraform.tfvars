# Terraform Variables File
# Update these values with your actual configuration

aws_region = "us-west-2"

vpc_id = "vpc-0ceae6b631752245e"

# Public subnets for Frontend/Backend
subnet_ids = [
  "subnet-0959f8eaf86ff7cee", # us-west-2a public
  "subnet-057f269eac2a5b130"  # us-west-2b public
]

# Private subnets for PostgreSQL
private_subnet_ids = [
  "subnet-06ebbb83ec105d2e2", # us-west-2a private
  "subnet-04a36e42773299fde", # us-west-2b private
]

key_name = "tata-key"

jenkins_instance_type = "m7i-flex.large"

allowed_ssh_cidr = "157.119.118.90/32" # Change to your IP

cluster_name = "ecommerce-cluster"

cluster_version = "1.34"
