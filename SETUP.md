# Complete Setup Guide - E-Commerce CI/CD Project

This guide provides step-by-step instructions to set up and run the E-Commerce microservices project locally and on AWS EKS.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [AWS Production Setup](#aws-production-setup)
4. [Jenkins EC2 Master-Slave Setup](#jenkins-ec2-master-slave-setup)
5. [CI/CD Pipeline Configuration](#cicd-pipeline-configuration)
6. [Verification & Testing](#verification--testing)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

#### 1. Node.js & npm
```bash
# Install Node.js 18+ (recommended: use nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18
node --version
npm --version
```

#### 2. Docker
```bash
# Install Docker Desktop (Windows/Mac) or Docker Engine (Linux)
# Verify installation
docker --version
```

> **Note:** For Amazon Linux 2023 (Jenkins EC2), Docker is installed automatically via `userdata-jenkins.sh` using the native Amazon Linux package: `dnf install -y docker`

#### 3. AWS CLI
```bash
# Install AWS CLI v2+
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region (us-west-2), output format (json)
```

#### 4. kubectl
```bash
# Install kubectl v1.28+
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

### AWS Account Setup

1. **Create AWS Account** if you don't have one
2. **Configure IAM User** with appropriate permissions:
   - AmazonEKSClusterPolicy
   - AmazonEKSWorkerNodePolicy
   - AmazonEC2ContainerRegistryFullAccess
   - AmazonRDSFullAccess
   - AmazonVPCFullAccess
   - IAMFullAccess (for setup)

---

## Local Development Setup

### Step 1: Clone Repository
```bash
git clone <your-repository-url>
cd E_Commerce-CICD_Final
```

### Step 2: Install Dependencies
```bash
# Install dependencies for all services
echo "Installing API Gateway dependencies..."
cd api-gateway && npm install && cd ..

echo "Installing Product Service dependencies..."
cd product-service && npm install && cd ..

echo "Installing Order Service dependencies..."
cd order-service && npm install && cd ..

echo "Installing User Service dependencies..."
cd user-service && npm install && cd ..

echo "Installing Frontend dependencies..."
cd frontend && npm install && cd ..

echo "All dependencies installed successfully!"
```

### Step 3: Environment Configuration
```bash
# Copy environment templates
cp api-gateway/.env.example api-gateway/.env
cp product-service/.env.example product-service/.env
cp order-service/.env.example order-service/.env
cp user-service/.env.example user-service/.env
cp frontend/.env.example frontend/.env

# Edit environment files with your settings
# Default values should work for local development
```

### Step 4: Start Local Development Stack

#### Option A: Docker Compose (Recommended)
```bash
cd docker

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps

# Stop services
docker-compose down
```

#### Option B: Manual Local Development
```bash
# Terminal 1 - Start PostgreSQL
docker run -d -p 5432:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=ecommerce \
  --name postgres-dev \
  postgres:15-alpine

# Terminal 2 - Start Product Service
cd product-service
npm run dev

# Terminal 3 - Start Order Service
cd order-service
npm run dev

# Terminal 4 - Start User Service
cd user-service
npm run dev

# Terminal 5 - Start API Gateway
cd api-gateway
npm run dev

# Terminal 6 - Start Frontend
cd frontend
npm run dev
```

### Step 5: Verify Local Setup
```bash
# Test health endpoints
curl http://localhost:3000/health  # API Gateway
curl http://localhost:3001/health  # Product Service
curl http://localhost:3002/health  # Order Service
curl http://localhost:3003/health  # User Service

# Test API endpoints
curl http://localhost:3000/api/products

# Test authentication
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'

# Access frontend
# Open http://localhost in browser
```

---

## AWS Production Setup

### Step 1: EKS Cluster (Terraform-managed)

The EKS cluster is created automatically by Terraform. To get kubeconfig:

```bash
# Configure kubectl for the EKS cluster
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster

# Verify connection
kubectl get nodes
```

### Step 2: Configure kubectl
```bash
# Update kubeconfig to connect to EKS
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 3: Setup Database

#### Option A: CloudNativePG (RECOMMENDED - Auto Failover)

CloudNativePG provides automatic failover, leader election, and native Kubernetes integration.

```bash
# Install CloudNativePG operator and deploy PostgreSQL cluster
chmod +x scripts/setup-cloudnativepg.sh
./scripts/setup-cloudnativepg.sh

# Wait for cluster to be ready
kubectl wait --for=condition=Ready cluster/postgres-cluster -n production --timeout=300s

# Create databases for microservices
chmod +x scripts/create-databases.sh
./scripts/create-databases.sh

# Verify cluster status
kubectl get cluster -n production
kubectl get pods -l cnpg.io/cluster=postgres-cluster -n production
```

**Prerequisites:**
- EBS CSI driver addon (installed automatically by Terraform during EKS creation)
- IAM role with `AmazonEBSCSIDriverPolicy` attached (already added to terraform/iam.tf)

**Features:**
- **Automatic Failover**: Kubernetes-native leader election promotes replica to primary automatically
- **Multi-AZ Distribution**: Pods spread across 2 availability zones via pod anti-affinity
- **Streaming Replication**: Synchronous replication between primary and replicas
- **Self-Healing**: Failed pods are automatically recreated and rejoin the cluster
- **Services**: 
  - `postgres-rw` - Primary (read-write)
  - `postgres-ro` - Replicas (read-only) 
  - `postgres` - Any instance
- **Databases**: `ecommerce`, `products_db`, `orders_db`, `users_db`

#### Option B: PostgreSQL StatefulSet (Manual Failover)

Simple StatefulSet setup (manual failover required if primary fails).

```bash
cd k8s/base

# Create StorageClass for EBS volumes
kubectl apply -f storageclass-postgres.yaml

# Deploy PostgreSQL
kubectl apply -f configmap-postgres.yaml -n production
kubectl apply -f secret-postgres.yaml -n production
kubectl apply -f service-postgres.yaml -n production
kubectl apply -f statefulset-postgres.yaml -n production

# Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n production --timeout=300s
```

#### Option B: AWS RDS (Recommended for Production)
```bash
# Make RDS setup script executable
chmod +x scripts/setup-rds.sh

# Run RDS setup (creates Multi-AZ RDS instance)
./scripts/setup-rds.sh

# This will create:
# - RDS PostgreSQL Multi-AZ instance
# - Database subnet group
# - Security group allowing EKS access
# - Database credentials stored in AWS Secrets Manager
```

### Step 4: Optional DevOps Tools

Deploy these tools on EKS if needed:

#### SonarQube & Nexus (Auto-Provisioned on Jenkins)

> **Note:** SonarQube and Nexus are automatically started as Docker containers on the Jenkins instance.
> No separate setup required!

| Service | URL | Credentials | How to Access |
|---------|-----|-------------|---------------|
| SonarQube | `http://<jenkins-ip>:9000` | admin / admin | Generate token in UI |
| Nexus | `http://<jenkins-ip>:8081` | admin / (auto-generated) | `docker exec nexus cat /nexus-data/admin.password` |

**Get Nexus Password:**
```bash
ssh -i your-key.pem ec2-user@<jenkins-public-ip>
docker exec nexus cat /nexus-data/admin.password
```

**Generate SonarQube Token:**
1. Login to SonarQube (`http://<jenkins-ip>:9000`) with admin/admin
2. User → My Account → Security → Generate Token
3. Copy token for Jenkins credential

#### Other Optional Tools

### Step 5: Build and Push Docker Images

#### Option A: Using Build Script
```bash
# Make build script executable
chmod +x scripts/build-images.sh

# Build all images with your DockerHub username
./scripts/build-images.sh your-dockerhub-username 1.0.0

# Push images to DockerHub
chmod +x scripts/push-images.sh
./scripts/push-images.sh your-dockerhub-username 1.0.0
```

#### Option B: Using Docker Compose
```bash
cd docker

# Build all images
docker-compose -f docker-compose.build.yml build

# Tag images for your registry
docker tag ecommerce-frontend:latest your-dockerhub-username/ecommerce-frontend:1.0.0
docker tag ecommerce-api-gateway:latest your-dockerhub-username/ecommerce-api-gateway:1.0.0
docker tag ecommerce-product-service:latest your-dockerhub-username/ecommerce-product-service:1.0.0
docker tag ecommerce-order-service:latest your-dockerhub-username/ecommerce-order-service:1.0.0
docker tag ecommerce-user-service:latest your-dockerhub-username/ecommerce-user-service:1.0.0

# Push to DockerHub
docker push your-dockerhub-username/ecommerce-frontend:1.0.0
docker push your-dockerhub-username/ecommerce-api-gateway:1.0.0
docker push your-dockerhub-username/ecommerce-product-service:1.0.0
docker push your-dockerhub-username/ecommerce-order-service:1.0.0
docker push your-dockerhub-username/ecommerce-user-service:1.0.0
```

### Step 6: Deploy Application to EKS

#### Create Namespaces
```bash
kubectl create namespace production
kubectl create namespace staging
```

#### Deploy Database (CloudNativePG Recommended)

```bash
cd k8s/base

# Deploy CloudNativePG cluster (automatic failover)
kubectl apply -f postgres-cloudnative.yaml -n production

# Wait for cluster
kubectl wait --for=condition=Ready cluster/postgres-cluster -n production --timeout=300s

# Verify
kubectl get cluster -n production
kubectl get pods -l cnpg.io/cluster=postgres-cluster -n production
```

**Or use StatefulSet (legacy):**
```bash
# Deploy PostgreSQL StatefulSet (manual failover)
kubectl apply -f configmap-postgres.yaml -n production
kubectl apply -f secret-postgres.yaml -n production
kubectl apply -f service-postgres.yaml -n production
kubectl apply -f statefulset-postgres.yaml -n production

# Wait for database
kubectl wait --for=condition=ready pod -l app=postgres -n production --timeout=300s
```

#### Deploy Application Services
```bash
cd k8s/base

# Update image tags in deployment files
# Replace 'your-dockerhub-username' with your actual DockerHub username

# Deploy ConfigMaps
kubectl apply -f configmap-api-gateway.yaml -n production
kubectl apply -f configmap-product-service.yaml -n production
kubectl apply -f configmap-order-service.yaml -n production
kubectl apply -f configmap-user-service.yaml -n production

# Deploy Secrets
kubectl apply -f secret-db.yaml -n production
kubectl apply -f secret-user-service.yaml -n production

# Deploy Services
kubectl apply -f deployment-api-gateway.yaml -n production
kubectl apply -f deployment-product-service.yaml -n production
kubectl apply -f deployment-order-service.yaml -n production
kubectl apply -f deployment-user-service.yaml -n production
kubectl apply -f deployment-frontend.yaml -n production

# Deploy Service definitions
kubectl apply -f service-api-gateway.yaml -n production
kubectl apply -f service-product-service.yaml -n production
kubectl apply -f service-order-service.yaml -n production
kubectl apply -f service-user-service.yaml -n production
kubectl apply -f service-frontend.yaml -n production

# Deploy HPA (Horizontal Pod Autoscaler)
kubectl apply -f hpa.yaml -n production

# Deploy Ingress (for external access)
kubectl apply -f ingress.yaml -n production
```

### Step 7: Verify Production Deployment
```bash
# Check all pods
kubectl get pods -n production

# Check services
kubectl get services -n production

# Check HPA
kubectl get hpa -n production

# Check Ingress
kubectl get ingress -n production

# Get frontend URL
kubectl get svc frontend -n production

# Port-forward for local testing
kubectl port-forward svc/frontend 8080:80 -n production
# Open http://localhost:8080 in browser
```

---

## Jenkins EC2 + EKS Setup (Terraform)

### Step 1: Deploy Infrastructure

```bash
cd terraform

# Update variables
vi terraform.tfvars
# Set: vpc_id, subnet_ids (at least 2), key_name, allowed_ssh_cidr

# Deploy both Jenkins and EKS
cd terraform
terraform init
terraform apply

# Get outputs
terraform output
```

### Step 2: Access Jenkins

1. **Get Jenkins URL:**
   ```bash
   terraform output jenkins_url
   # Output: http://<public-ip>:8080
   ```

2. **Login:** admin / admin123
3. **Change password** immediately

### Step 3: Configure EKS Access on Jenkins

```bash
# SSH to Jenkins instance
ssh -i your-key.pem ec2-user@<jenkins-public-ip>

# Configure kubectl for EKS (instance already has aws cli and kubectl)
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster

# Verify
kubectl get nodes
```

### Step 4: Verify Pre-installed Tools

All tools are pre-installed via userdata:
```bash
# SSH to Jenkins and verify
ssh -i your-key.pem ec2-user@<jenkins-public-ip>

# Check Jenkins service
systemctl status jenkins

# Check other tools
docker --version       # Docker
kubectl version        # kubectl
node --version         # Node.js
trivy version          # Trivy
sonar-scanner --version # SonarQube Scanner

# Check SonarQube and Nexus containers
docker ps | grep -E 'sonarqube|nexus'
docker logs sonarqube  # View SonarQube startup logs
docker logs nexus      # View Nexus startup logs
```

---

## CI/CD Pipeline Configuration

### Create CI Pipeline (ecommerce-ci)

- New Item → Pipeline
- Name: `ecommerce-ci`
- Definition: Pipeline script from SCM
- Repository: Your GitHub repo
- Script Path: `jenkins/Jenkinsfile-CI`

### Create CD Pipeline (ecommerce-cd)

- New Item → Pipeline
- Name: `ecommerce-cd`
- Definition: Pipeline script from SCM
- Repository: Your GitHub repo
- Script Path: `jenkins/Jenkinsfile-CD`

### Configure Credentials

In Jenkins: Manage Jenkins → Manage Credentials → Global

1. **dockerhub-credentials** (Username/Password)
   - Your DockerHub username and password/token
   - Jenkinsfiles automatically read DockerHub username from this credential

2. **aws-credentials** (AWS Credentials)
   - AWS Access Key and Secret Key

3. **github-token** (Secret text)
   - GitHub personal access token

4. **sonarqube-token** (Secret text)
   - Generate from SonarQube: User → My Account → Security → Generate Token
   - SonarQube URL: `http://localhost:9000` (from Jenkins instance)

5. **nexus-credentials** (Username/Password)
   - Username: `admin`
   - Password: Get from `docker exec nexus cat /nexus-data/admin.password`
   - Nexus URL: `http://localhost:8081` (from Jenkins instance)

> **Note:** The Jenkinsfiles (`jenkins/Jenkinsfile-CI` and `jenkins/Jenkinsfile-CD`) are pre-configured to use these credential IDs. The `DOCKERHUB_USERNAME` and `K8S_REPO` variables are automatically set from credentials or the repository URL.

### Configure GitHub Webhook

1. Get URL from Terraform output:
   ```bash
   terraform output jenkins_url
   # Use: http://<ip>:8080/github-webhook/
   ```

2. In GitHub repo: Settings → Webhooks → Add webhook
   - Payload URL: `http://<jenkins-ip>:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Push

### Optional: Deploy SonarQube & Nexus on EKS (Not Required)

> **Note:** SonarQube and Nexus are already running as Docker containers on the Jenkins instance.
> Only run these if you want separate EKS deployments (not needed for this setup):

```bash
# Deploy on EKS (optional)
chmod +x scripts/setup-sonarqube.sh && ./scripts/setup-sonarqube.sh
chmod +x scripts/setup-nexus.sh && ./scripts/setup-nexus.sh
```

---

## Verification & Testing

### Local Testing
```bash
# Test all health endpoints
curl http://localhost:3000/health
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health

# Test API functionality
curl http://localhost:3000/api/products

# Test user registration
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'

# Test user login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'
```

### Production Testing
```bash
# Get application URL
kubectl get ingress -n production

# Test endpoints through ALB
curl http://<alb-url>/api/products
curl http://<alb-url>/health

# Check pod logs
kubectl logs -f deployment/api-gateway -n production
kubectl logs -f deployment/product-service -n production
kubectl logs -f deployment/order-service -n production
kubectl logs -f deployment/user-service -n production
kubectl logs -f deployment/frontend -n production
```

### Load Testing
```bash
# Install Apache Bench
ab -n 1000 -c 10 http://localhost:3000/api/products

# Or use hey
go install github.com/rakyll/hey@latest
hey -n 1000 -c 10 http://localhost:3000/api/products
```

---

## Troubleshooting

### Common Issues & Solutions

#### 1. Port Already in Use
```bash
# Check what's using the port
netstat -tulpn | grep :3000

# Kill the process
sudo kill -9 <PID>

# Or use different ports in docker-compose.yml
```

#### 2. Database Connection Failed
```bash
# Check PostgreSQL container
docker logs postgres-dev

# Verify database is running
docker exec -it postgres-dev psql -U postgres -d ecommerce -c "SELECT 1;"

# Check network connectivity
docker network ls
docker network inspect docker_ecommerce-network
```

#### 3. Pod Not Starting in EKS
```bash
# Describe pod for detailed error
kubectl describe pod <pod-name> -n production

# Check pod logs
kubectl logs <pod-name> -n production

# Check events
kubectl get events -n production --sort-by=.metadata.creationTimestamp
```

#### 4. Image Pull Errors
```bash
# Check if image exists
docker pull your-dockerhub-username/ecommerce-api-gateway:1.0.0

# Check image pull secret
kubectl get secret dockerhub-secret -n production -o yaml

# Create image pull secret if missing
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email \
  -n production
```

#### 5. Jenkins Pipeline Failures
```bash
# For single Jenkins EC2 instance:
# SSH to Jenkins and check logs
ssh -i your-key.pem ec2-user@<jenkins-ip>
sudo tail -f /var/log/jenkins/jenkins.log

# Check if all tools are installed
which docker kubectl aws trivy sonar-scanner

# Verify Jenkins can access EKS
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster
kubectl get nodes
```

#### 6. EKS Connection Issues from Jenkins
```bash
# On Jenkins instance, verify EKS access
aws eks describe-cluster --name ecommerce-cluster --region us-west-2

# Check if kubeconfig is configured
cat ~/.kube/config

# Update kubeconfig if needed
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster
```

#### 8. EBS CSI Driver Issues (PVC Stuck Pending)

If PostgreSQL PVC is stuck in `Pending` status:

```bash
# Check PVC status
kubectl get pvc -n production

# Check PVC events for errors
kubectl describe pvc postgres-cluster-1 -n production

# Check EBS CSI driver pods
kubectl get pods -n kube-system | grep ebs

# Check EBS CSI controller logs
kubectl logs -n kube-system deployment/ebs-csi-controller -c ebs-plugin

# Check addon status
eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2
```

**Common Solutions:**

1. **Verify IAM Policy Attached:**
   ```bash
   aws iam list-attached-role-policies --role-name eks-node-role
   # Should show: AmazonEBSCSIDriverPolicy
   ```

2. **Recreate Addon (if needed):**
   ```bash
   # Delete existing addon
   eksctl delete addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2
   
   # Reinstall via eksctl
   eksctl create addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2
   
   # Wait for ACTIVE status
   eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2
   ```

3. **Delete and Recreate PVC:**
   ```bash
   # Delete PostgreSQL cluster to release PVC
   kubectl delete cluster postgres-cluster -n production
   
   # Delete stuck PVC
   kubectl delete pvc postgres-cluster-1 -n production
   
   # Recreate cluster
   kubectl apply -f k8s/base/postgres-cloudnative.yaml -n production
   ```

#### 9. Ingress Not Working
```bash
# Check Ingress controller
kubectl get pods -n ingress-nginx

# Check Ingress rules
kubectl describe ingress api-gateway-ingress -n production

# Check ALB in AWS Console
```

### Performance Issues

#### High Memory Usage
```bash
# Check resource usage
kubectl top pods -n production

# Add resource limits to deployments
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

#### Database Performance
```bash
# For CloudNativePG (check cluster status)
kubectl get cluster postgres-cluster -n production
kubectl describe cluster postgres-cluster -n production

# Check cluster logs
kubectl logs -l cnpg.io/cluster=postgres-cluster,cnpg.io/instanceRole=primary -n production

# For StatefulSet (check connections)
kubectl exec -it postgres-0 -n production -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

#### CloudNativePG Troubleshooting
```bash
# Check cluster status
kubectl get cluster postgres-cluster -n production

# Check if all instances are ready
kubectl get pods -l cnpg.io/cluster=postgres-cluster -n production

# View primary instance logs
kubectl logs postgres-cluster-1 -n production

# View replica logs
kubectl logs postgres-cluster-2 -n production

# Check failover status
kubectl get cluster postgres-cluster -o jsonpath='{.status}' -n production | jq

# Manual failover (if needed)
kubectl cnpg failover postgres-cluster -n production

# Check network connectivity between instances
kubectl exec -it postgres-cluster-1 -n production -- pg_isready -h postgres-cluster-2
```

### Security Issues

#### SSL/TLS Certificate Issues
```bash
# Install cert-manager for automatic SSL
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Update Ingress with TLS configuration
```

#### RBAC Issues
```bash
# Check service account permissions
kubectl auth can-i create pods --as=system:serviceaccount:production:default

# Create appropriate RBAC rules
```

---

## Cleanup Commands

### Local Cleanup
```bash
# Stop Docker Compose
cd docker && docker-compose down -v

# Remove all containers
docker container prune -f

# Remove all images
docker image prune -a -f
```

### AWS Cleanup
```bash
# Destroy all Terraform-managed resources
cd terraform
terraform destroy

# Or delete EKS cluster manually if needed
aws eks delete-cluster --name ecommerce-cluster --region us-west-2

# Delete other resources manually from AWS Console if terraform destroy missed anything
```

---

## Support

For additional help:
1. Check the project README.md file
2. Review logs for specific error messages
3. Consult AWS documentation for EKS and RDS
4. Check Jenkins documentation for pipeline issues
5. Review Kubernetes documentation for deployment issues

Remember: This is a production-grade system with multiple moving parts. Start with local development, then gradually move to AWS deployment as you become familiar with the components.
