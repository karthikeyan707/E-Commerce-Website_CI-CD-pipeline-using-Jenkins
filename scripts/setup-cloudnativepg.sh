#!/bin/bash
# Setup CloudNativePG Operator for PostgreSQL with Automatic Failover
# This script installs the CloudNativePG operator and deploys the PostgreSQL cluster

set -e

echo "================================"
echo "CloudNativePG Operator Setup"
echo "================================"

# Check if kubectl is configured
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "Error: kubectl is not configured or cannot connect to cluster"
    echo "Run: aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster"
    exit 1
fi

echo ""
echo "Step 1: Installing CloudNativePG Operator..."
echo "================================"

# Install CloudNativePG operator using kubectl
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.22/releases/cnpg-1.22.1.yaml

# Wait for operator to be ready
echo "Waiting for CloudNativePG operator to be ready..."
kubectl wait --for=condition=Available deployment/cnpg-controller-manager -n cnpg-system --timeout=120s

echo ""
echo "Step 2: Creating PostgreSQL credentials secret..."
echo "================================"

# Create namespace if not exists
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

# Create secret for PostgreSQL credentials (change these in production!)
kubectl create secret generic postgres-credentials \
  --from-literal=username=postgres \
  --from-literal=password=postgres \
  --from-literal=database=ecommerce \
  -n production \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Step 3: Creating init SQL for multiple databases..."
echo "================================"

# Create init SQL ConfigMap for multiple databases
cat << 'EOF' | kubectl apply -n production -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgres-init-sql
stringData:
  init-databases.sql: |
    -- Create databases for each microservice
    CREATE DATABASE products_db;
    CREATE DATABASE orders_db;
    CREATE DATABASE users_db;
    
    -- Create application user (optional)
    CREATE USER ecommerce_user WITH PASSWORD 'ecommerce_pass';
    
    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE products_db TO ecommerce_user;
    GRANT ALL PRIVILEGES ON DATABASE orders_db TO ecommerce_user;
    GRANT ALL PRIVILEGES ON DATABASE users_db TO ecommerce_user;
    GRANT ALL PRIVILEGES ON DATABASE ecommerce TO ecommerce_user;
EOF

echo ""
echo "Step 4: Installing EBS CSI Driver (EKS Managed Addon)..."
echo "================================"

# Check if EBS CSI driver addon is already installed
ADDON_STATUS=$(eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2 2>/dev/null | grep -v "NAME" | awk '{print $3}' || echo "NOT_INSTALLED")

if [ "$ADDON_STATUS" = "ACTIVE" ]; then
    echo "EBS CSI driver addon is already active, skipping..."
elif [ "$ADDON_STATUS" = "CREATING" ]; then
    echo "EBS CSI driver addon is already being created, waiting for it to be ready..."
    echo "This may take 3-5 minutes..."
    while [ "$ADDON_STATUS" != "ACTIVE" ]; do
        sleep 30
        ADDON_STATUS=$(eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2 2>/dev/null | grep -v "NAME" | awk '{print $3}')
        echo "Current status: $ADDON_STATUS"
    done
else
    echo "Installing EBS CSI driver managed addon via eksctl..."
    echo "This may take 3-5 minutes..."
    eksctl create addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2 --force
    
    # Wait for addon to be active
    echo "Waiting for EBS CSI driver addon to be active..."
    while [ "$ADDON_STATUS" != "ACTIVE" ]; do
        sleep 30
        ADDON_STATUS=$(eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2 2>/dev/null | grep -v "NAME" | awk '{print $3}')
        echo "Current status: $ADDON_STATUS"
    done
    echo "EBS CSI driver addon is active!"
fi

# Remove any manually installed EBS CSI driver pods if they exist
kubectl delete deployment ebs-csi-controller -n kube-system 2>/dev/null || true
kubectl delete daemonset ebs-csi-node -n kube-system 2>/dev/null || true
echo "EBS CSI driver setup complete!"

echo ""
echo "Step 5: Creating StorageClass for PostgreSQL..."
echo "================================"

# Create StorageClass for gp3 multi-az
cat << 'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-multi-az
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Retain
EOF

echo ""
echo "Step 6: Deploying CloudNativePG Cluster..."
echo "================================"

# Deploy the PostgreSQL cluster
kubectl apply -f k8s/base/postgres-cloudnative.yaml -n production

echo ""
echo "Step 7: Waiting for PostgreSQL cluster to be ready..."
echo "================================"

echo "Note: This may take 5-10 minutes for the cluster to be fully ready."
echo "If this times out, check status with: kubectl get cluster -n production"

# Wait for cluster to be ready
kubectl wait --for=condition=Ready cluster/postgres-cluster -n production --timeout=600s || {
    echo ""
    echo "Warning: Timeout waiting for cluster to be ready."
    echo "The cluster may still be initializing. Check status with:"
    echo "  kubectl get cluster -n production"
    echo "  kubectl get pods -l cnpg.io/cluster=postgres-cluster -n production"
    echo "  kubectl describe pvc -n production"
}

echo ""
echo "================================"
echo "CloudNativePG Setup Complete!"
echo "================================"
echo ""
echo "Cluster Information:"
echo "-------------------"
echo "Cluster Name: postgres-cluster"
echo "Namespace: production"
echo "Instances: 3 (1 Primary + 2 Replicas)"
echo ""
echo "Services:"
echo "--------"
echo "  postgres-rw    - Primary (read-write)"
echo "  postgres-ro    - Replicas (read-only)"
echo "  postgres       - Any instance"
echo ""
echo "Check Status:"
echo "------------"
echo "  kubectl get cluster -n production"
echo "  kubectl get pods -l cnpg.io/cluster=postgres-cluster -n production"
echo ""
echo "Connect to Primary:"
echo "------------------"
echo "  kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres"
echo ""
echo "Databases Created:"
echo "-----------------"
echo "  - ecommerce (main)"
echo "  - products_db"
echo "  - orders_db"
echo "  - users_db"
echo ""
echo "Failover:"
echo "--------"
echo "  Automatic failover is enabled!"
echo "  If primary fails, a replica will be promoted automatically."
echo ""
echo "Backup (optional):"
echo "-----------------"
echo "  Edit k8s/base/postgres-cloudnative.yaml to configure S3 backups"
echo ""
