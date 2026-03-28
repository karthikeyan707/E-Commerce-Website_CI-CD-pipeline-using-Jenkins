#!/bin/bash
set -e

echo "=== Nexus Repository Manager Setup on EKS ==="

NAMESPACE="nexus"
NEXUS_VOLUME_SIZE="20Gi"

echo "Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Creating persistent volume claim..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${NEXUS_VOLUME_SIZE}
EOF

echo "Deploying Nexus..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nexus
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nexus
  template:
    metadata:
      labels:
        app: nexus
    spec:
      containers:
        - name: nexus
          image: sonatype/nexus3:latest
          ports:
            - containerPort: 8081
          volumeMounts:
            - name: nexus-data
              mountPath: /nexus-data
          env:
            - name: INSTALL4J_ADD_VM_PARAMS
              value: "-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g"
      volumes:
        - name: nexus-data
          persistentVolumeClaim:
            claimName: nexus-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nexus
  namespace: ${NAMESPACE}
spec:
  selector:
    app: nexus
  ports:
    - port: 8081
      targetPort: 8081
  type: LoadBalancer
EOF

echo "Waiting for Nexus to be ready..."
kubectl rollout status deployment/nexus -n ${NAMESPACE} --timeout=300s

echo "Getting initial admin password..."
sleep 30
kubectl exec -n ${NAMESPACE} deployment/nexus -- cat /nexus-data/admin.password 2>/dev/null || echo "Check password manually"

echo "=== Nexus Setup Complete ==="
echo "Access Nexus at: kubectl get svc nexus -n ${NAMESPACE}"
echo "Default credentials: admin / password from above"
