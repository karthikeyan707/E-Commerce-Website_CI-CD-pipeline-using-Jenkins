# E-Commerce CI/CD Project

A production-grade microservices-based E-Commerce system with complete CI/CD pipeline on AWS EKS. Features a React frontend, JWT authentication, and 5 products with shopping cart functionality.

## Architecture Overview

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
│      │           PostgreSQL StatefulSet (Multi-AZ)              ││
│      │           Primary: postgres-0  (AZ-1)                    ││
│      │           Replica: postgres-1   (AZ-2)                   ││
│      │           Databases: products_db, orders_db, users_db      ││
│      └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
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
│       └── statefulset-postgres.yaml  # PostgreSQL HA
├── jenkins/
│   ├── Jenkinsfile-CI   # GitHub webhook trigger, manual approval
│   └── Jenkinsfile-CD   # Deployment pipeline
├── docker/
│   └── docker-compose.yml   # Full local stack with frontend
└── scripts/
    ├── build-images.sh
    └── push-images.sh
```

## Prerequisites

- AWS CLI v2+
- kubectl v1.28+
- eksctl v0.160+
- Docker v24+
- Node.js 18+
- Helm v3+

## Quick Start

### 1. Infrastructure Setup

#### 1.1 Create EKS Cluster
```bash
chmod +x scripts/setup-eks.sh
./scripts/setup-eks.sh
```

#### 1.2 Deploy PostgreSQL StatefulSet (Multi-AZ in EKS)
```bash
# Create StorageClass for EBS gp3 encrypted volumes
kubectl apply -f k8s/base/storageclass-postgres.yaml

# Deploy PostgreSQL with streaming replication across AZs
kubectl apply -f k8s/base/configmap-postgres.yaml
kubectl apply -f k8s/base/secret-postgres.yaml
kubectl apply -f k8s/base/service-postgres.yaml
kubectl apply -f k8s/base/statefulset-postgres.yaml
```

**Note:** For production, consider using AWS RDS Multi-AZ instead:
```bash
chmod +x scripts/setup-rds.sh
./scripts/setup-rds.sh
```

#### 1.3 Setup DevOps Tools
```bash
# Jenkins
chmod +x scripts/setup-jenkins.sh
./scripts/setup-jenkins.sh

# SonarQube
chmod +x scripts/setup-sonarqube.sh
./scripts/setup-sonarqube.sh

# Nexus
chmod +x scripts/setup-nexus.sh
./scripts/setup-nexus.sh

# Trivy
chmod +x scripts/setup-trivy.sh
./scripts/setup-trivy.sh
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
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster
```

#### 4.2 Create Namespace
```bash
kubectl create namespace production
kubectl create namespace staging
```

#### 4.3 Apply PostgreSQL StatefulSet
```bash
cd k8s/base

# StorageClass (one-time setup)
kubectl apply -f storageclass-postgres.yaml

# PostgreSQL
kubectl apply -f configmap-postgres.yaml -n production
kubectl apply -f secret-postgres.yaml -n production
kubectl apply -f service-postgres.yaml -n production
kubectl apply -f statefulset-postgres.yaml -n production

# Verify PostgreSQL is running
kubectl get pods -l app=postgres -n production
kubectl get pvc -n production
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

### 5. CI/CD Pipeline Setup

#### 5.1 Jenkins Configuration
1. Access Jenkins at `http://<jenkins-loadbalancer>:8080`
2. Install required plugins:
   - Pipeline
   - Git
   - Docker Pipeline
   - Kubernetes CLI
   - SonarQube Scanner
   - Slack Notification

3. Configure credentials:
   - `dockerhub-credentials` - DockerHub username/password
   - `aws-credentials` - AWS access key/secret
   - `github-token` - GitHub personal access token
   - `sonarqube-token` - SonarQube authentication token
   - `nexus-credentials` - Nexus username/password

**Note:** The CI pipeline uses `docker-compose` to build all images in parallel. See `docker/docker-compose.build.yml`.

4. Create CI Pipeline:
   - New Item → Pipeline
   - Name: `ecommerce-ci`
   - Pipeline script from SCM
   - Repository URL: your GitHub repo
   - Script Path: `jenkins/Jenkinsfile-CI`

5. Create CD Pipeline:
   - New Item → Pipeline
   - Name: `ecommerce-cd`
   - Pipeline script from SCM
   - Script Path: `jenkins/Jenkinsfile-CD`

#### 5.2 SonarQube Configuration
1. Access SonarQube at `http://<sonarqube-loadbalancer>:9000`
2. Default credentials: `admin/admin`
3. Create projects for each service:
   - `ecommerce-api-gateway`
   - `ecommerce-product-service`
   - `ecommerce-order-service`
   - `ecommerce-user-service`
   - `ecommerce-frontend`
4. Generate tokens and add to Jenkins credentials

#### 5.3 Nexus Configuration
1. Access Nexus at `http://<nexus-loadbalancer>:8081`
2. Create blob stores and repositories:
   - docker-hosted (port 8082)
   - docker-proxy (Docker Hub)
   - docker-group (combine hosted + proxy)
3. Create `ecommerce-artifacts` raw repository

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
6. **Smoke Tests** - Run health checks
7. **Commit Manifests** - GitOps update

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
