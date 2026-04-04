# Jenkins EC2 Master-Slave Setup Guide

This guide explains how to set up Jenkins Master-Slave architecture on AWS EC2 with Terraform for the E-Commerce CI/CD project.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (us-west-2)                       │
│                                                                      │
│  ┌──────────────────────┐         ┌──────────────────────┐          │
│  │  Jenkins Master      │         │  Jenkins Slave       │          │
│  │  (c7i-flex.large)    │◄───────►│  (c7i-flex.large)    │          │
│  │  - Port 8080 (UI)    │  JNLP   │  - Build Agent       │          │
│  │  - Port 50000 (JNLP) │         │  - Docker + K8s      │          │
│  │  - 20GB EBS          │         │  - 30GB EBS          │          │
│  └──────────────────────┘         └──────────────────────┘          │
│            │                                 │                       │
│            │                                 │                       │
│            ▼                                 ▼                       │
│   ┌─────────────────────┐          ┌─────────────────────┐          │
│   │  GitHub Webhook     │          │  Deploy to EKS      │          │
│   │  Triggers Build     │          │  (us-west-2)        │          │
│   └─────────────────────┘          └─────────────────────┘          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Files Created

### Terraform Infrastructure
- `terraform/main.tf` - EC2 instances, security groups, IAM roles
- `terraform/terraform.tfvars` - Variables (update with your values)

### User Data Scripts
- `terraform/userdata-master.sh` - Jenkins Master installation
- `terraform/userdata-slave.sh` - Jenkins Slave with all build tools

### Updated Jenkinsfiles
- `jenkins/Jenkinsfile-CI` - CI pipeline for master-slave
- `jenkins/Jenkinsfile-CD` - CD pipeline for master-slave

## Quick Start

### Step 1: Update Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
aws_region = "us-west-2"
vpc_id     = "vpc-xxxxxxxxxxxxxxxxx"      # Your existing VPC
subnet_id  = "subnet-xxxxxxxxxxxxxxxxx"   # Public subnet
key_name   = "your-key-pair-name"         # Your AWS key pair
allowed_ssh_cidr = "xx.xx.xx.xx/32"       # Your IP address
```

### Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply (creates both instances)
terraform apply

# Save outputs
terraform output > terraform-outputs.txt
```

### Step 3: Wait for User Data to Complete

Both instances run setup scripts on first boot. Wait 5-10 minutes.

```bash
# Check Master setup logs
ssh -i your-key.pem ec2-user@<master-public-ip> 'tail -f /var/log/user-data.log'

# Check Slave setup logs
ssh -i your-key.pem ec2-user@<slave-public-ip> 'tail -f /var/log/user-data.log'
```

### Step 4: Configure Jenkins Slave on Master

1. **Access Jenkins Master UI**
   ```
   http://<master-public-ip>:8080
   ```
   - Default credentials: `admin` / `admin123`

2. **Add Slave Node**
   - Go to: Manage Jenkins → Manage Nodes and Clouds → New Node
   - Node name: `jenkins-slave-1`
   - Type: `Permanent Agent`
   - Configure:
     - Remote root directory: `/var/lib/jenkins-agent`
     - Labels: `jenkins-slave`
     - Launch method: `Launch agent by connecting it to the controller`
     - Custom WorkDir path: `/var/lib/jenkins-agent`
     - Internal data directory: `remoting`

3. **Get Agent Secret**
   - Click on the new node
   - Copy the secret from the command shown

4. **Configure Slave Agent**
   SSH into Slave and run:
   ```bash
   sudo /usr/local/bin/setup-agent.sh <master-private-ip> <agent-secret> jenkins-slave-1
   ```

   Or manually edit the service file:
   ```bash
   sudo vi /etc/systemd/system/jenkins-agent.service
   # Update JENKINS_URL, JENKINS_SECRET, JENKINS_AGENT_NAME
   sudo systemctl daemon-reload
   sudo systemctl enable jenkins-agent
   sudo systemctl start jenkins-agent
   ```

5. **Verify Connection**
   - In Jenkins Master UI, check node status
   - Should show "Agent is connected"

### Step 5: Configure Jenkins Master

1. **Install Required Plugins**
   - Go to: Manage Jenkins → Plugins → Available
   - Install:
     - Pipeline
     - Git
     - GitHub Integration
     - Docker Pipeline
     - Kubernetes CLI
     - Kubernetes Credentials
     - SonarQube Scanner
     - Slack Notification
     - Blue Ocean (optional)

2. **Configure Credentials**
   - Go to: Manage Jenkins → Manage Credentials → Global
   - Add:
     - `dockerhub-credentials` (Username/Password)
     - `aws-credentials` (AWS Credentials)
     - `github-token` (Secret text)
     - `sonarqube-token` (Secret text)
     - `nexus-credentials` (Username/Password)

3. **Configure Tools**
   - Go to: Manage Jenkins → Tools
   - Add NodeJS installations (already on slave, but register them)

### Step 6: Create Pipeline Jobs

1. **Create CI Pipeline**
   - New Item → Pipeline
   - Name: `ecommerce-ci`
   - Pipeline definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your GitHub repo URL
   - Credentials: github-token
   - Script Path: `jenkins/Jenkinsfile-CI`

2. **Create CD Pipeline**
   - New Item → Pipeline
   - Name: `ecommerce-cd`
   - Pipeline definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your GitHub repo URL
   - Credentials: github-token
   - Script Path: `jenkins/Jenkinsfile-CD`

### Step 7: Configure GitHub Webhook

1. **Get Jenkins Webhook URL**
   ```
   http://<master-public-ip>:8080/github-webhook/
   ```

2. **Add Webhook in GitHub**
   - Go to: Repository → Settings → Webhooks
   - Payload URL: `http://<master-public-ip>:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Just the push event
   - Add webhook

### Step 8: Test the Pipeline

1. **Push code to GitHub**
   ```bash
   git add .
   git commit -m "Test CI/CD pipeline"
   git push origin main
   ```

2. **Verify in Jenkins**
   - Check CI pipeline is triggered
   - Monitor build on Slave node
   - Approve deployment to trigger CD

## Troubleshooting

### Jenkins Master Issues

```bash
# Check Jenkins service status
sudo systemctl status jenkins

# View Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Restart Jenkins
sudo systemctl restart jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Jenkins Slave Issues

```bash
# Check agent service status
sudo systemctl status jenkins-agent

# View agent logs
sudo journalctl -u jenkins-agent -f

# Restart agent
sudo systemctl restart jenkins-agent

# Test tools
which docker && docker --version
which kubectl && kubectl version --client
which eksctl && eksctl version
which aws && aws --version
```

### Connection Issues

```bash
# Test network connectivity from Slave to Master
curl -v telnet://<master-private-ip>:50000

# Check security groups allow port 50000
# Both instances should have proper security group rules
```

### Pipeline Failures

```bash
# Check agent is online in Jenkins UI
# Review console output in Blue Ocean or classic UI
# Check tool versions match pipeline requirements
```

## Slave Tools Installed

The Jenkins Slave has all necessary tools pre-installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Java 17 | Amazon Corretto | Jenkins agent runtime |
| Node.js 18 | Latest | Frontend/Backend builds |
| npm | Latest | Package management |
| Docker | Latest | Container builds |
| Docker Compose | Latest | Multi-container builds |
| AWS CLI v2 | Latest | AWS operations |
| kubectl | Latest | Kubernetes deployment |
| eksctl | Latest | EKS cluster management |
| Helm 3 | Latest | Kubernetes package manager |
| Trivy | Latest | Security scanning |
| SonarQube Scanner | 5.0.1 | Code quality analysis |
| jq | Latest | JSON processing |
| yq | Latest | YAML processing |
| GitHub CLI | Latest | GitHub operations |

## Security Considerations

1. **Restrict SSH Access**
   - Update `allowed_ssh_cidr` in terraform.tfvars
   - Use your IP address, not `0.0.0.0/0`

2. **Secure Jenkins**
   - Change default admin password immediately
   - Enable CSRF protection
   - Use matrix-based security

3. **Rotate Credentials**
   - Use AWS Secrets Manager for sensitive data
   - Rotate GitHub tokens regularly
   - Use IAM roles instead of access keys where possible

4. **Network Security**
   - Place instances in private subnets if possible
   - Use NAT Gateway for outbound traffic
   - Enable VPC Flow Logs

## Maintenance

### Backup Jenkins Master

```bash
# Automated daily backup to S3 (already configured in userdata)
# Manual backup:
sudo /usr/local/bin/backup-jenkins.sh
```

### Update Jenkins

```bash
# SSH to Master
ssh -i your-key.pem ec2-user@<master-ip>

# Update Jenkins
sudo dnf update -y
sudo systemctl restart jenkins
```

### Monitor Disk Space

```bash
# Check disk usage
df -h

# Clean Docker images
docker system prune -af
```

## Cost Optimization

1. **Use Spot Instances for Slave** (optional)
   - Modify Terraform to use spot instances for slave
   - Add fallback to on-demand

2. **Auto-shutdown Schedule**
   - Stop instances during non-business hours
   - Use Lambda functions for scheduled start/stop

3. **Right-size Instances**
   - Monitor CPU/memory usage
   - Adjust instance types based on actual needs

## Next Steps

1. Configure SonarQube for code quality
2. Set up Slack notifications
3. Add monitoring with CloudWatch
4. Configure SSL/TLS for Jenkins UI
5. Set up automated backups
6. Add more slave nodes for parallel builds

## Support

For issues:
1. Check instance logs: `/var/log/user-data.log`
2. Review Jenkins logs: `/var/log/jenkins/`
3. Check Terraform state: `terraform show`
4. Verify security group rules in AWS Console
