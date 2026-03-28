#!/bin/bash
set -e

echo "=== Trivy Security Scanner Setup ==="

# Install Trivy on Jenkins agent or local machine
echo "Installing Trivy..."

if command -v trivy &> /dev/null; then
    echo "Trivy is already installed"
    trivy --version
else
    # Install Trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    
    echo "Trivy installed successfully"
    trivy --version
fi

echo "=== Setting up Trivy in Jenkins ==="

# Create Trivy configuration for Jenkins
cat <<'EOF' > trivy-jenkins-config.yaml
# Trivy Configuration for Jenkins
exit-code: 0
severity:
  - HIGH
  - CRITICAL
scan:
  scanners:
    - vuln
    - misconfig
    - secret
output: table
EOF

echo "Configuration file created: trivy-jenkins-config.yaml"

echo "=== Trivy Setup Complete ==="
echo "Usage examples:"
echo "  trivy image <image-name>"
echo "  trivy fs --scanners vuln,secret,misconfig <path>"
echo "  trivy config <path-to-k8s-manifests>"
