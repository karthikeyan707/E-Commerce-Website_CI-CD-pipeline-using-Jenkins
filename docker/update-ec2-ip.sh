#!/bin/bash
# Script to automatically update docker-compose.yml with EC2 public IP

# Get EC2 public IP from instance metadata
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

if [ -z "$EC2_IP" ]; then
    echo "Error: Could not fetch EC2 public IP. Are you running on EC2?"
    exit 1
fi

echo "Detected EC2 Public IP: $EC2_IP"

# Update docker-compose.yml with the correct IP
sed -i "s|VITE_API_URL: http://[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+:3000|VITE_API_URL: http://${EC2_IP}:3000|g" docker-compose.yml

echo "Updated docker-compose.yml with IP: $EC2_IP"
echo "Run 'docker-compose up -d' to apply changes"
