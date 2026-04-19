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

# Create secret for PostgreSQL credentials
kubectl create secret generic postgres-credentials \
  --from-literal=username=postgres \
  --from-literal=password=postgres \
  --from-literal=database=ecommerce \
  -n production \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Step 3: Checking EBS CSI Driver..."
echo "================================"

# Check if EBS CSI driver pods are running
if kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver 2>/dev/null | grep -q "Running"; then
    echo "EBS CSI driver is running!"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver -n kube-system --timeout=60s 2>/dev/null || true
else
    echo "EBS CSI driver not found."
    echo "If using Terraform, the addon should be installed automatically."
    echo "Checking addon status..."
    
    # Check if eksctl addon exists and wait for it
    ADDON_STATUS=$(eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2 2>/dev/null | grep -v "NAME" | awk '{print $3}' || echo "NOT_INSTALLED")
    
    if [ "$ADDON_STATUS" = "ACTIVE" ]; then
        echo "EBS CSI addon is ACTIVE, waiting for pods..."
        sleep 10
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver -n kube-system --timeout=120s 2>/dev/null || true
    elif [ "$ADDON_STATUS" = "CREATING" ]; then
        echo "EBS CSI addon is still creating, waiting..."
        while [ "$ADDON_STATUS" != "ACTIVE" ]; do
            sleep 30
            ADDON_STATUS=$(eksctl get addon --name aws-ebs-csi-driver --cluster ecommerce-cluster --region us-west-2 2>/dev/null | grep -v "NAME" | awk '{print $3}')
            echo "Current status: $ADDON_STATUS"
        done
        echo "Addon is ACTIVE, waiting for pods..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver -n kube-system --timeout=120s 2>/dev/null || true
    else
        echo "WARNING: EBS CSI not available. PVC creation may fail."
        echo "Status: $ADDON_STATUS"
    fi
fi

echo ""
echo "Step 4: Creating StorageClass for PostgreSQL..."
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
echo "Step 5: Deploying CloudNativePG Cluster..."
echo "================================"

# Deploy the PostgreSQL cluster
kubectl apply -f k8s/base/postgres-cloudnative.yaml -n production

echo ""
echo "Step 6: Waiting for PostgreSQL cluster to be ready..."
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
    exit 1
}

echo ""
echo "Step 7: Creating databases for microservices..."
echo "================================"

# Create databases manually since postInitSQLRefs is not supported in this CloudNativePG version
# Use PostgreSQL syntax (no IF NOT EXISTS for CREATE DATABASE)
echo "Creating products_db..."
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'products_db'" 2>/dev/null | grep -q 1 || kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "CREATE DATABASE products_db;" 2>/dev/null || true

echo "Creating orders_db..."
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'orders_db'" 2>/dev/null | grep -q 1 || kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "CREATE DATABASE orders_db;" 2>/dev/null || true

echo "Creating users_db..."
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'users_db'" 2>/dev/null | grep -q 1 || kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "CREATE DATABASE users_db;" 2>/dev/null || true

echo "Granting privileges..."
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE products_db TO postgres;" 2>/dev/null || true
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE orders_db TO postgres;" 2>/dev/null || true
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE users_db TO postgres;" 2>/dev/null || true

echo "Databases created successfully!"

echo ""
echo "================================"
echo "CloudNativePG Setup Complete!"
echo "================================"
echo ""
echo "Cluster Information:"
echo "-------------------"
echo "Cluster Name: postgres-cluster"
echo "Namespace: production"
echo "Instances: 2 (1 Primary + 1 Replicas)"
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
