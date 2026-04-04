#!/bin/bash
# User Data Script for Jenkins Server (Master + Build Agent)
# Amazon Linux 2023
# Installs: Jenkins, Docker, AWS CLI, kubectl, Node.js, Trivy, Sonar Scanner
# Runs: SonarQube (Docker), Nexus (Docker) for CI/CD pipeline
# Region: us-west-2
exec > >(tee /var/log/user-data.log) 2>&1

echo "========== Starting Jenkins Setup =========="
date

# Wait for network
until ping -c1 8.8.8.8 &>/dev/null; do sleep 1; done

echo "Updating system packages..."
dnf -y update

echo "Refreshing metadata..."
dnf -y clean all
dnf -y makecache

# Install base dependencies
echo "Installing base dependencies..."
dnf install -y wget curl unzip git fontconfig

#===============================================================================
# Install Java
#===============================================================================
echo "Installing Java..."
dnf install -y java-17-amazon-corretto-devel

echo "export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto" >> /etc/profile
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile
source /etc/profile

java -version

#===============================================================================
# Install Jenkins (WAR file method - works on Amazon Linux 2023)
#===============================================================================
echo "Installing Jenkins via WAR file..."

# Create directories and user
mkdir -p /opt /var/lib/jenkins
useradd --system --create-home --home-dir /var/lib/jenkins jenkins 2>/dev/null || true

# Download Jenkins WAR (Latest Stable)
curl -L -o /opt/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war
chown jenkins:jenkins /opt/jenkins.war
chmod 755 /opt/jenkins.war

# Create systemd service
cat > /etc/systemd/system/jenkins.service << 'EOF'
[Unit]
Description=Jenkins Server
After=network.target

[Service]
Type=simple
User=jenkins
Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto"
Environment="JENKINS_HOME=/var/lib/jenkins"
WorkingDirectory=/var/lib/jenkins
ExecStart=/usr/lib/jvm/java-17-amazon-corretto/bin/java -jar /opt/jenkins.war --httpPort=8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R jenkins:jenkins /var/lib/jenkins

# Create admin user and disable setup wizard
mkdir -p /var/lib/jenkins/init.groovy.d

cat > /var/lib/jenkins/init.groovy.d/disable-setup-wizard.groovy << 'EOF'
import jenkins.model.*
import jenkins.install.*
def instance = Jenkins.getInstance()
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOF

cat > /var/lib/jenkins/init.groovy.d/create-admin-user.groovy << 'EOF'
import jenkins.model.*
import hudson.security.*
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
instance.setSecurityRealm(hudsonRealm)
def user = hudsonRealm.createAccount("admin", "admin123")
user.save()
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)
instance.save()
EOF

chown -R jenkins:jenkins /var/lib/jenkins
chmod 755 /var/lib/jenkins/init.groovy.d/*.groovy

# Start Jenkins
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

echo "Jenkins installation complete"

#===============================================================================
# Install Docker (Amazon Linux 2023 native package)
#===============================================================================
echo "Installing Docker..."

# Install Docker from Amazon Linux 2023 repositories
dnf install -y docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Start Docker
systemctl enable docker
systemctl start docker

# Verify installations
docker --version
docker-compose --version

# Add jenkins user to docker group
usermod -aG docker jenkins

#===============================================================================
# Install AWS CLI
#===============================================================================
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
aws --version

#===============================================================================
# Install kubectl
#===============================================================================
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl version --client

#===============================================================================
# Install Node.js & npm
#===============================================================================
echo "Installing Node.js 18..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs
node --version
npm --version

#===============================================================================
# Install Trivy
#===============================================================================
echo "Installing Trivy..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
ln -s /usr/local/bin/trivy /usr/bin/trivy
trivy version

#===============================================================================
# Install SonarQube Scanner
#===============================================================================
echo "Installing SonarQube Scanner..."
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip sonar-scanner-cli-5.0.1.3006-linux.zip -d /opt
mv /opt/sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner
chmod -R 755 /opt/sonar-scanner
chown -R jenkins:jenkins /opt/sonar-scanner
ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
rm -f sonar-scanner-cli-5.0.1.3006-linux.zip
sonar-scanner --version

#===============================================================================
# Configure Jenkins Plugins (after Jenkins starts)
#===============================================================================
echo "Waiting for Jenkins to start..."
sleep 45

echo "Configuring Jenkins plugins..."
cat > /tmp/plugins.txt << 'EOF'
workflow-aggregator
git
github
docker-workflow
kubernetes-cli
kubernetes-credentials
credentials-binding
AWS Credentials
sonarqube-scanner
nexus-artifact-uploader
EOF

# Install plugins if CLI is available
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    curl -L -o /usr/local/bin/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar 2>/dev/null || true
    if [ -f /usr/local/bin/jenkins-cli.jar ]; then
        while read plugin; do
            java -jar /usr/local/bin/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123 install-plugin $plugin 2>/dev/null || true
        done < /tmp/plugins.txt
        java -jar /usr/local/bin/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123 safe-restart 2>/dev/null || true
    fi
fi

# Wait for Jenkins to restart
sleep 30

#===============================================================================
# Start SonarQube (Docker)
#===============================================================================
echo "Starting SonarQube container..."
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e SONAR_WEB_JAVAOPTS="-Xmx512m -Xms128m" \
  -v sonarqube_data:/opt/sonarqube/data \
  --restart unless-stopped \
  sonarqube:10.3-community

# Wait for SonarQube to be ready
echo "Waiting for SonarQube to start..."
sleep 60

#===============================================================================
# Start Nexus (Docker)
#===============================================================================
echo "Starting Nexus container..."
docker run -d --name nexus \
  -p 8081:8081 \
  -e INSTALL4J_ADD_VM_PARAMS="-Xms512m -Xmx512m -XX:MaxDirectMemorySize=512m" \
  -v nexus_data:/nexus-data \
  --restart unless-stopped \
  sonatype/nexus3:3.65.0

# Wait for Nexus to be ready
echo "Waiting for Nexus to start..."
sleep 60

# Create Nexus blob store and repository for artifacts
echo "Configuring Nexus..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Wait for Nexus admin password file
docker exec nexus cat /nexus-data/admin.password 2>/dev/null || echo "changeme"

#===============================================================================
# Final Output
#===============================================================================
echo ""
echo "========== Setup Complete =========="
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Credentials: admin / admin123"
echo ""
echo "SonarQube URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "SonarQube Credentials: admin / admin"
echo ""
echo "Nexus URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081"
echo "Nexus Admin Password: $(docker exec nexus cat /nexus-data/admin.password 2>/dev/null || echo 'Check: docker exec nexus cat /nexus-data/admin.password')"
echo ""
echo "Installed Tools:"
echo "  - Jenkins (port 8080)"
echo "  - Docker & Docker Compose"
echo "  - AWS CLI"
echo "  - kubectl"
echo "  - Node.js & npm"
echo "  - Trivy"
echo "  - SonarQube Scanner"
echo "  - SonarQube Server (Docker, port 9000)"
echo "  - Nexus Server (Docker, port 8081)"
echo ""
date
echo "======================================"
