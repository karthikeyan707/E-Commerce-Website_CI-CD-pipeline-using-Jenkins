#!/bin/bash
set -e

echo "=== Jenkins Setup on EKS ==="

# Variables
NAMESPACE="jenkins"
JENKINS_VOLUME_SIZE="10Gi"

echo "Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "Creating persistent volume claim..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${JENKINS_VOLUME_SIZE}
EOF

echo "Deploying Jenkins..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
        - name: jenkins
          image: jenkins/jenkins:lts-jdk17
          ports:
            - containerPort: 8080
            - containerPort: 50000
          volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins_home
          env:
            - name: JAVA_OPTS
              value: "-Djenkins.install.runSetupWizard=false"
      volumes:
        - name: jenkins-home
          persistentVolumeClaim:
            claimName: jenkins-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: ${NAMESPACE}
spec:
  selector:
    app: jenkins
  ports:
    - port: 8080
      targetPort: 8080
  type: LoadBalancer
EOF

echo "Waiting for Jenkins to be ready..."
kubectl rollout status deployment/jenkins -n ${NAMESPACE} --timeout=300s

echo "Getting initial admin password..."
sleep 10
kubectl exec -n ${NAMESPACE} deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword

echo "=== Jenkins Setup Complete ==="
echo "Access Jenkins at: kubectl get svc jenkins -n ${NAMESPACE}"
