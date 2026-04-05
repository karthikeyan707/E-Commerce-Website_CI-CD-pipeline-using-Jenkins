# E-Commerce CI/CD Project

A production-grade microservices-based E-Commerce system with complete CI/CD pipeline on AWS EKS using a single Jenkins EC2 instance. Features a React frontend, JWT authentication, and 5 products with shopping cart functionality.

## Architecture Overview

### Application Architecture
```
┌─────────────────────────────────────────────────────────────────────┐
│                           React Frontend (Port 80)                   │
│                    SPA - Products, Cart, Orders, Auth                │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
┌───────────────────────────────────▼─────────────────────────────────┐
│                              AWS EKS                                │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │                     Ingress (ALB)                          │   │
│  └───────────────────────┬───────────────────────────────────┘   │
│                          │                                        │
│  ┌───────────────────────▼───────────────────────────────────┐     │
│  │                API Gateway (2 replicas)                  │     │
│  │             Port: 3000, Rate Limiting                  │     │
│  └───────────────┬───────────────────────┬──────────────────┘     │
│                  │                       │                          │
│      ┌───────────▼──────────┐  ┌────────▼──────────┐  ┌───────────┐│
│      │   Product Service    │  │  Order Service  │  │User Service│
│      │   (3 replicas)       │  │  (3 replicas)   │  │(2 replicas)│
│      │   Port: 3001         │  │  Port: 3002     │  │Port: 3003  │
│      └───────────┬──────────┘  └────────┬──────────┘  └─────┬─────┘│
│                  │                     │                   │      │
│      ┌───────────▼─────────────────────▼───────────────────▼────┐│
│      │           PostgreSQL (CloudNativePG)                          ││
│      │           ├─ 2 Instances (1 Primary + 1 Replica)             ││
│      │           ├─ Auto Failover via Kubernetes Leader Election    ││
│      │           ├─ Multi-AZ Distribution                          ││
│      │           └─ Databases: products_db, orders_db, users_db     ││
│      └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### CI/CD Architecture (Single Jenkins on EC2 + EKS)
```
┌─────────────────────────────────────────────────────────────────────┐
│                     AWS Cloud (us-west-2)                           │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────┐     │
│  │              Jenkins Server (EC2)                         │     │
│  │              c7i-flex.large                               │     │
│  │  ┌──────────────────────────────────────────────────────┐ │     │
│  │  │  Port 8080 - Jenkins UI                             │ │     │
│  │  │  ├─ Pipeline Controller                            │ │     │
│  │  │  ├─ GitHub Webhook Handler                         │ │     │
│  │  │  └─ Build Executor                                 │ │     │
│  │  └──────────────────────────────────────────────────────┘ │     │
│  │                                                          │     │
│  │  Installed Tools:                                        │     │
│  │  ├─ Docker                                               │     │
│  │  ├─ Node.js & npm                                        │     │
│  │  ├─ AWS CLI                                              │     │
│  │  ├─ kubectl                                              │     │
│  │  ├─ Trivy (Security Scan)                                │     │
│  │  └─ SonarQube Scanner                                    │     │
│  │                                                          │     │
│  │  30GB EBS Storage                                        │     │
│  └──────────────┬───────────────────────────────────────────┘     │
│                 │                                                   │
│                 │  CI: Checkout → Build → Test → Sonar → Push    │
│                 │  CD: Manual Trigger → Deploy to EKS             │
│                 │                                                   │
│                 ▼                                                   │
│      ┌──────────────────┐        ┌──────────────────┐              │
│      │    GitHub        │        │   EKS Cluster    │              │
│      │  (Push Trigger)  │        │  (Application)   │              │
│      └──────────────────┘        └──────────────────┘              │
└─────────────────────────────────────────────────────────────────────┘

Pipeline Flow:
GitHub Push → Jenkins (CI: Build/Test/Scan/Push) → Manual Approval → Jenkins (CD: Deploy to EKS)
```

## Services

| Service | Port | Description | Database |
|---------|------|-------------|----------|
| Frontend | 80 | React SPA (Products, Cart, Orders) | None |
| API Gateway | 3000 | Reverse proxy, rate limiting, routing | None |
| Product Service | 3001 | Product CRUD, 5 seeded products | PostgreSQL |
| Order Service | 3002 | Order management, user order history | PostgreSQL |
| User Service | 3003 | JWT authentication (register/login) | PostgreSQL |

## API Endpoints

### Authentication (via API Gateway)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/register` | POST | Register new user (username, password) |
| `/api/auth/login` | POST | Login and get JWT token |
| `/api/users/profile` | GET | Get user profile (JWT required) |

### Products
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/products` | GET | List all 5 products |
| `/api/products/:id` | GET | Get single product |

### Orders (JWT Required)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/orders` | POST | Create order with cart items |
| `/api/orders/user/:userId` | GET | Get user's order history |

## Project Structure

```
E_Commerce-CICD/
├── frontend/             # React SPA (Products, Cart, Auth, Orders)
│   ├── src/
│   │   ├── pages/        # Home, Cart, Login, Register, Orders
│   │   ├── components/   # Navbar
│   │   └── context/      # AuthContext, CartContext
│   └── public/
├── api-gateway/          # API Gateway microservice
├── product-service/      # Product Service with 5 seeded products
├── order-service/        # Order Service (linked to users)
├── user-service/         # JWT Authentication service
├── k8s/                  # Kubernetes manifests
│   └── base/
│       ├── deployment-*.yaml      # All service deployments
│       ├── service-*.yaml         # All service definitions
│       ├── configmap-*.yaml       # Service configurations
│       ├── secret-*.yaml          # Database credentials
│       ├── postgres-cloudnative.yaml # CloudNativePG (Auto Failover)
│       ├── statefulset-postgres.yaml # PostgreSQL StatefulSet (Legacy)
│       └── storageclass-postgres.yaml # EBS StorageClass
├── jenkins/              # Jenkins Pipeline Scripts
│   ├── Jenkinsfile-CI    # CI pipeline (runs on Slave)
│   └── Jenkinsfile-CD    # CD pipeline (deploys to EKS)
├── terraform/            # Terraform Infrastructure
│   ├── providers.tf      # Terraform providers
│   ├── variables.tf      # Input variables
│   ├── data.tf           # Data sources (AMI)
│   ├── vpc.tf            # Security groups
│   ├── iam.tf            # IAM roles and policies
│   ├── jenkins.tf        # Jenkins EC2 + Elastic IP
│   ├── eks.tf            # EKS cluster + node group
│   ├── outputs.tf        # Output values
│   ├── terraform.tfvars  # Variable values
│   └── userdata-jenkins.sh # Jenkins setup with all tools
├── docker/
│   ├── docker-compose.yml    # Full local stack
│   └── docker-compose.build.yml # Build configuration
├── scripts/
│   ├── build-images.sh
│   ├── push-images.sh
│   ├── setup-cloudnativepg.sh  # CloudNativePG operator setup
│   ├── setup-rds.sh
│   ├── setup-nexus.sh
│   └── setup-sonarqube.sh
└── SETUP.md              # Complete setup guide

## Prerequisites

- AWS CLI v2+
- kubectl v1.28+
- Docker v24+
- Node.js 18+

## Quick Start

### Option 1: Local Development (Fastest)

```bash
# Install dependencies
cd api-gateway && npm install && cd ..
cd product-service && npm install && cd ..
cd order-service && npm install && cd ..
cd user-service && npm install && cd ..
cd frontend && npm install && cd ..

# Start with Docker Compose
cd docker
docker-compose up -d

# Access: http://localhost (Frontend), http://localhost:3000 (API)
```

### Option 2: Production Deployment with CI/CD (Automated)

#### Step 1: Deploy Jenkins & EKS with Terraform

```bash
cd terraform

# Update terraform.tfvars with your VPC, subnets, and key pair
# vpc_id = "vpc-xxxxx"
# subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
# key_name = "your-key-pair"

# Deploy infrastructure (Jenkins + EKS)
terraform init
terraform apply

# Get outputs
terraform output
# - jenkins_url: http://<ip>:8080
# - eks_kubeconfig_command: aws eks update-kubeconfig ...
```

#### Step 2: Configure Jenkins, SonarQube & Nexus

Jenkins instance automatically starts SonarQube and Nexus as Docker containers:

| Service | URL | Default Credentials | Get Token/Password |
|---------|-----|---------------------|-------------------|
| Jenkins | `http://<jenkins-ip>:8080` | admin / admin123 | - |
| SonarQube | `http://<jenkins-ip>:9000` | admin / admin | Generate token in UI |
| Nexus | `http://<jenkins-ip>:8081` | admin / (see below) | `docker exec nexus cat /nexus-data/admin.password` |

**1. Access Jenkins:**
```bash
cd terraform
terraform output jenkins_url
# Open in browser, login: admin / admin123
```

**2. Setup SonarQube:**

a. **Login:** `http://<jenkins-ip>:9000` with admin/admin

b. **Create Project:**
   - Click **Projects** → **Create Project** → **Manually**
   - Project key: `ecommerce-app`
   - Display name: `E-Commerce Application`
   - Main branch: `main`
   - Click **Set Up**

c. **Generate Token:**
   - User menu (top right) → **My Account** → **Security**
   - Token name: `jenkins-ci`
   - Click **Generate** and copy the token

**3. Setup Nexus:**

a. **Get Admin Password:**
```bash
ssh -i your-key.pem ec2-user@<jenkins-ip>
docker exec nexus cat /nexus-data/admin.password
```

b. **Login:** `http://<jenkins-ip>:8081` with admin / (password from above)

c. **Create Repository:**
   - Click **Settings** (gear icon) → **Repositories** → **Create repository**
   - Select: **`raw (hosted)`**
   - Name: `ecommerce-artifacts`
   - Online: ✓ Checked
   - Deployment Policy: `Allow redeploy`
   - Click **Create repository**

**4. Configure Jenkins Credentials:**

Navigate to: Manage Jenkins → Manage Credentials → Global → Add Credentials

1. **DockerHub Credentials**
   - Kind: Username with password
   - ID: `dockerhub-credentials`

2. **AWS Credentials**
   - Kind: AWS Credentials
   - ID: `aws-credentials`

3. **GitHub Token**
   - Kind: Secret text
   - ID: `github-token`
   - Generate classic token from GitHub: Settings → Developer settings → Personal access tokens → Tokens (classic) → scope: `repo`

4. **SonarQube Token**
   - Kind: Secret text
   - ID: `sonarqube-token`
   - Secret: (token from SonarQube UI step above)

5. **Nexus Credentials**
   - Kind: Username with password
   - ID: `nexus-credentials`
   - Username: `admin`
   - Password: (password from docker exec command above)

#### Step 3: Configure GitHub Webhook

```
http://<jenkins-public-ip>:8080/github-webhook/
```

#### Step 4: Deploy

Push code to GitHub → CI pipeline auto-triggers → Manual approve → CD deploys to EKS

---

### 1. Infrastructure Setup (Detailed)

#### 1.1 EKS Cluster (Terraform-managed)
```bash
# EKS cluster is created by Terraform. Get kubeconfig:
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster

# Verify
kubectl get nodes
```

#### 1.2 Deploy PostgreSQL
```bash
# Option A: CloudNativePG (RECOMMENDED - Auto Failover)
# Provides automatic failover, leader election, and native Kubernetes integration
chmod +x scripts/setup-cloudnativepg.sh
./scripts/setup-cloudnativepg.sh

# Option B: StatefulSet (Manual Failover - Legacy)
# Simple setup but requires manual intervention for failover
kubectl apply -f k8s/base/storageclass-postgres.yaml
kubectl apply -f k8s/base/configmap-postgres.yaml -n production
kubectl apply -f k8s/base/secret-postgres.yaml -n production
kubectl apply -f k8s/base/service-postgres.yaml -n production
kubectl apply -f k8s/base/statefulset-postgres.yaml -n production

# Option C: AWS RDS (Production - Managed Service)
chmod +x scripts/setup-rds.sh
./scripts/setup-rds.sh
```

### 2. Local Development

#### 2.1 Install Dependencies
```bash
cd api-gateway && npm install
cd ../product-service && npm install
cd ../order-service && npm install
cd ../user-service && npm install
cd ../frontend && npm install
```

#### 2.2 Environment Configuration
```bash
cp api-gateway/.env.example api-gateway/.env
cp product-service/.env.example product-service/.env
cp order-service/.env.example order-service/.env
cp user-service/.env.example user-service/.env
cp frontend/.env.example frontend/.env
```

Edit the `.env` files with your database credentials and service URLs.

#### 2.3 Start Full Stack with Docker Compose (Recommended)
```bash
cd docker
docker-compose up -d

# Access:
# Frontend: http://localhost (port 80)
# API: http://localhost:3000
```

#### 2.4 Start Services Locally (Individual)
```bash
# Terminal 1 - PostgreSQL
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=password postgres:15-alpine

# Terminal 2 - Product Service
cd product-service && npm run dev

# Terminal 3 - Order Service  
cd order-service && npm run dev

# Terminal 4 - User Service
cd user-service && npm run dev

# Terminal 5 - API Gateway
cd api-gateway && npm run dev

# Terminal 6 - Frontend (Vite dev server)
cd frontend && npm run dev
```

#### 2.4 Test Endpoints
```bash
# Health Checks
curl http://localhost:3000/health
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health

# API Gateway
curl http://localhost:3000/api/products
curl http://localhost:3000/api/orders

# Authentication
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'

curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'
```

### 3. Docker Build with Docker Compose

#### 3.1 Build All Images at Once
```bash
# Option 1: Using docker-compose build file
cd docker
docker-compose -f docker-compose.build.yml build

# Option 2: Using helper script (builds + tags with version)
chmod +x scripts/build-images.sh
./scripts/build-images.sh your-dockerhub-username 1.0.0

# Option 3: Build with custom tags
IMAGE_TAG=1.0.0 DOCKERHUB_USERNAME=myuser docker-compose -f docker-compose.build.yml build
```

#### 3.2 Run Full Local Stack (with PostgreSQL)
```bash
cd docker
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

#### 3.3 Push to DockerHub
```bash
chmod +x scripts/push-images.sh
./scripts/push-images.sh your-dockerhub-username 1.0.0
```

### 4. Kubernetes Deployment

#### 4.1 Configure kubectl
```bash
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster
```

#### 4.2 Create Namespace
```bash
kubectl create namespace production
kubectl create namespace staging
```

#### 4.3 Apply PostgreSQL (CloudNativePG - Recommended)

```bash
# Deploy CloudNativePG with automatic failover
chmod +x scripts/setup-cloudnativepg.sh
./scripts/setup-cloudnativepg.sh

# Wait for cluster to be ready (2 instances: 1 primary + 1 replica)
kubectl wait --for=condition=Ready cluster/postgres-cluster -n production --timeout=300s

# Create databases for microservices
chmod +x scripts/create-databases.sh
./scripts/create-databases.sh

# Verify
kubectl get cluster -n production
kubectl get pods -l cnpg.io/cluster=postgres-cluster -n production
```

**CloudNativePG Features:**
- **Automatic Failover**: Kubernetes-native leader election promotes replica to primary automatically
- **Multi-AZ Distribution**: Pods spread across 2 availability zones via pod anti-affinity
- **Prerequisites**: 
  - EBS CSI driver addon installed automatically by Terraform during EKS creation
  - IAM role with `AmazonEBSCSIDriverPolicy` attached
- **Streaming Replication**: Synchronous replication between primary and replicas
- **Self-Healing**: Failed pods are automatically recreated and rejoin the cluster

**Services:**
- `postgres-rw` - Connects to primary (read-write)
- `postgres-ro` - Connects to replicas (read-only)
- `postgres` - Connects to any instance

#### Alternative: PostgreSQL StatefulSet (Manual Failover)

```bash
# Legacy StatefulSet setup (manual failover required)
kubectl apply -f k8s/base/storageclass-postgres.yaml
kubectl apply -f k8s/base/configmap-postgres.yaml -n production
kubectl apply -f k8s/base/secret-postgres.yaml -n production
kubectl apply -f k8s/base/service-postgres.yaml -n production
kubectl apply -f k8s/base/statefulset-postgres.yaml -n production
```

#### 4.4 Apply Application Configurations
```bash
# ConfigMaps
kubectl apply -f configmap-api-gateway.yaml -n production
kubectl apply -f configmap-product-service.yaml -n production
kubectl apply -f configmap-order-service.yaml -n production
kubectl apply -f configmap-user-service.yaml -n production

# Secrets
kubectl apply -f secret-db.yaml -n production
kubectl apply -f secret-user-service.yaml -n production

# Deployments
kubectl apply -f deployment-api-gateway.yaml -n production
kubectl apply -f deployment-product-service.yaml -n production
kubectl apply -f deployment-order-service.yaml -n production
kubectl apply -f deployment-user-service.yaml -n production
kubectl apply -f deployment-frontend.yaml -n production

# Services
kubectl apply -f service-user-service.yaml -n production
kubectl apply -f service-frontend.yaml -n production

# HPA
kubectl apply -f hpa.yaml -n production

# Ingress (Production only)
kubectl apply -f ingress.yaml -n production
```

#### 4.5 Access the Application
```bash
# Get frontend LoadBalancer URL
kubectl get svc frontend -n production

# Or port-forward for local testing
kubectl port-forward svc/frontend 8080:80 -n production
# Open http://localhost:8080 in browser
```

#### 4.6 Verify Deployment
```bash
# Check pods
kubectl get pods -n production

# Check services
kubectl get svc -n production

# Check HPA
kubectl get hpa -n production

# View logs
kubectl logs -f deployment/api-gateway -n production
```

### 5. CI/CD Pipeline Setup (Single Jenkins on EC2)

#### 5.1 Access Jenkins

1. **Get Jenkins URL from Terraform output:**
   ```bash
   cd terraform
   terraform output jenkins_url
   ```

2. **Access Jenkins:**
   ```
   http://<jenkins-public-ip>:8080
   ```
   - Default credentials: `admin` / `admin123`
   - Change password immediately after first login

#### 5.2 Verify Pre-installed Plugins

The following plugins are already installed via userdata:
- Pipeline, Git, GitHub Integration
- Docker Pipeline, Kubernetes CLI, Kubernetes Credentials
- Credentials Binding
- SonarQube Scanner, Nexus Artifact Uploader

If any are missing, install via: Manage Jenkins → Plugins → Available

#### 5.3 Configure Credentials

Navigate to: Manage Jenkins → Manage Credentials → Global → Add Credentials

1. **DockerHub Credentials**
   - Kind: Username with password
   - ID: `dockerhub-credentials`

2. **AWS Credentials**
   - Kind: AWS Credentials
   - ID: `aws-credentials`

3. **GitHub Token**
   - Kind: Secret text
   - ID: `github-token`

4. **SonarQube Token**
   - Kind: Secret text
   - ID: `sonarqube-token`

5. **Nexus Credentials**
   - Kind: Username with password
   - ID: `nexus-credentials`

#### 5.4 Create Pipeline Jobs

1. **Create CI Pipeline:**
   - New Item → Pipeline → Name: `ecommerce-ci`
   - Pipeline script from SCM
   - Repository URL: your GitHub repo
   - Script Path: `jenkins/Jenkinsfile-CI`

2. **Create CD Pipeline:**
   - New Item → Pipeline → Name: `ecommerce-cd`
   - Pipeline script from SCM
   - Repository URL: your GitHub repo
   - Script Path: `jenkins/Jenkinsfile-CD`

#### 5.5 Configure GitHub Webhook

1. **Get Jenkins URL:**
   ```bash
   cd terraform && terraform output jenkins_url
   ```

2. **Add Webhook in GitHub:**
   - Repository → Settings → Webhooks → Add webhook
   - Payload URL: `http://<jenkins-public-ip>:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Just the push event

#### 5.6 Optional: Deploy SonarQube & Nexus on EKS (Not needed - already running on Jenkins)

> **Note:** SonarQube and Nexus are already running as Docker containers on the Jenkins instance.
> Only run these if you want separate EKS deployments:

```bash
# Deploy on EKS (optional - not required)
chmod +x scripts/setup-sonarqube.sh && ./scripts/setup-sonarqube.sh
chmod +x scripts/setup-nexus.sh && ./scripts/setup-nexus.sh
```

## API Endpoints

### API Gateway
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/products` | List products (proxied) |
| POST | `/api/products` | Create product (proxied) |
| GET | `/api/products/:id` | Get product (proxied) |
| GET | `/api/orders` | List orders (proxied) |
| POST | `/api/orders` | Create order (proxied) |
| GET | `/api/orders/:id` | Get order (proxied) |

### Product Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/products` | List products with pagination |
| POST | `/products` | Create new product |
| GET | `/products/:id` | Get product by ID |
| PUT | `/products/:id` | Update product |
| DELETE | `/products/:id` | Delete product |

### Order Service
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/orders` | List orders with pagination |
| POST | `/orders` | Create new order |
| GET | `/orders/:id` | Get order by ID |
| PUT | `/orders/:id/status` | Update order status |
| DELETE | `/orders/:id` | Delete order |

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Products Table
```sql
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  sku VARCHAR(100) UNIQUE NOT NULL,
  category VARCHAR(100),
  stock INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Orders Table
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id INTEGER NOT NULL REFERENCES users(id),
  customer_email VARCHAR(255),
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  status VARCHAR(50) DEFAULT 'PENDING',
  shipping_address TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id),
  product_id UUID NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## CI/CD Pipeline Stages

### CI Pipeline (Jenkinsfile-CI)
1. **Trigger** - GitHub webhook on push
2. **Checkout** - Clone repository
3. **Build** - Install dependencies
4. **Unit Tests** - Run test suites with coverage
5. **SonarQube Analysis** - Code quality scan
6. **Quality Gate** - Enforce quality standards
7. **Docker Build** - Build container images
8. **Trivy Scan** - Security vulnerability scan
9. **Push to DockerHub** - Publish images
10. **Upload to Nexus** - Archive artifacts
11. **Manual Approval** - Approve deployment
12. **Trigger CD** - Start deployment pipeline

### CD Pipeline (Jenkinsfile-CD)
1. **Checkout K8s Manifests** - Pull Kubernetes configs
2. **Configure AWS** - Setup EKS access
3. **Update Image Tags** - Update deployment manifests
4. **Deploy to EKS** - Apply to Kubernetes
5. **Verify Rollout** - Check deployment status
6. **Commit Manifests** - GitOps update

## Production Checklist

- [ ] Update all placeholder values in YAML files
- [ ] Configure proper resource limits (CPU/Memory)
- [ ] Set up SSL certificates for Ingress
- [ ] Configure proper database passwords in Secrets
- [ ] Set up backup for RDS databases
- [ ] Configure CloudWatch monitoring
- [ ] Set up alerting (Slack/Email)
- [ ] Enable deletion protection on RDS
- [ ] Configure WAF rules for ALB
- [ ] Set up VPC Flow Logs

## Troubleshooting

### Common Issues

**Pod not starting**
```bash
kubectl describe pod <pod-name> -n production
kubectl logs <pod-name> -n production --previous
```

**Database connection failed**
- Verify RDS security group allows EKS node access
- Check DB credentials in Kubernetes Secret
- Ensure DB subnet group is correctly configured

**Ingress not working**
```bash
kubectl get ingress -n production
kubectl describe ingress api-gateway-ingress -n production
```

**HPA not scaling**
```bash
kubectl describe hpa api-gateway-hpa -n production
kubectl top pods -n production
```

## Security Best Practices

1. **Never commit secrets** - Use Kubernetes Secrets or AWS Secrets Manager
2. **Non-root containers** - All services run as non-root user
3. **Network policies** - Restrict pod-to-pod communication
4. **Image scanning** - Trivy scans all images before deployment
5. **RBAC** - Use least-privilege IAM roles
6. **Encryption** - RDS encryption at rest and in transit
7. **Private subnets** - EKS nodes in private subnets
8. **Security groups** - Restrict access to necessary ports only

## Monitoring & Logging

### CloudWatch Integration
```bash
# Fluent Bit for log aggregation
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

### Prometheus & Grafana (Optional)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and feature requests, please use GitHub Issues.
