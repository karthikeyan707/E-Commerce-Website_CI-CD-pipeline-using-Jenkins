#!/bin/bash
set -e

echo "=== SonarQube Setup on EKS ==="

NAMESPACE="sonarqube"
SONARQUBE_VOLUME_SIZE="10Gi"
POSTGRES_VOLUME_SIZE="10Gi"

echo "Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Creating PostgreSQL for SonarQube..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonar-postgres-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${POSTGRES_VOLUME_SIZE}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonar-postgres
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonar-postgres
  template:
    metadata:
      labels:
        app: sonar-postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: sonar
            - name: POSTGRES_PASSWORD
              value: sonar
            - name: POSTGRES_DB
              value: sonar
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: sonar-postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: sonar-postgres
  namespace: ${NAMESPACE}
spec:
  selector:
    app: sonar-postgres
  ports:
    - port: 5432
EOF

echo "Creating SonarQube..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${SONARQUBE_VOLUME_SIZE}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      initContainers:
        - name: init-sysctl
          image: busybox
          command: ['sh', '-c', 'sysctl -w vm.max_map_count=262144']
          securityContext:
            privileged: true
      containers:
        - name: sonarqube
          image: sonarqube:lts-community
          ports:
            - containerPort: 9000
          env:
            - name: SONAR_JDBC_URL
              value: jdbc:postgresql://sonar-postgres:5432/sonar
            - name: SONAR_JDBC_USERNAME
              value: sonar
            - name: SONAR_JDBC_PASSWORD
              value: sonar
          volumeMounts:
            - name: sonarqube-data
              mountPath: /opt/sonarqube/data
      volumes:
        - name: sonarqube-data
          persistentVolumeClaim:
            claimName: sonarqube-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: sonarqube
  namespace: ${NAMESPACE}
spec:
  selector:
    app: sonarqube
  ports:
    - port: 9000
      targetPort: 9000
  type: LoadBalancer
EOF

echo "=== SonarQube Setup Initiated ==="
echo "Default credentials: admin / admin"
echo "Access SonarQube at: kubectl get svc sonarqube -n ${NAMESPACE}"
