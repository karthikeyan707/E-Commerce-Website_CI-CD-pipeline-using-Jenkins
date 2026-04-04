#!/bin/bash
# Create databases after PostgreSQL is running
# Run this after the CloudNativePG cluster is ready

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=Ready cluster/postgres-cluster -n production --timeout=300s

echo "Creating databases..."
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "CREATE DATABASE products_db;"
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "CREATE DATABASE orders_db;"
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "CREATE DATABASE users_db;"
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE products_db TO postgres;"
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE orders_db TO postgres;"
kubectl exec -it postgres-cluster-1 -n production -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE users_db TO postgres;"

echo "Databases created successfully!"
