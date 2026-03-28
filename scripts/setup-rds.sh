#!/bin/bash
set -e

echo "=== AWS RDS PostgreSQL Multi-AZ Setup ==="

# Variables
DB_INSTANCE_IDENTIFIER="ecommerce-postgres"
DB_NAME="ecommerce"
DB_USER="postgres"
DB_PASSWORD="your-secure-password-here"
DB_INSTANCE_CLASS="db.t3.medium"
REGION="us-east-1"
VPC_SECURITY_GROUP_ID="sg-xxxxxxxxx"
DB_SUBNET_GROUP_NAME="ecommerce-db-subnet-group"

# Create DB Subnet Group (if not exists)
echo "Creating DB Subnet Group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name ${DB_SUBNET_GROUP_NAME} \
    --db-subnet-group-description "E-Commerce DB Subnet Group" \
    --subnet-ids '["subnet-xxx","subnet-yyy","subnet-zzz"]' \
    --region ${REGION} || echo "DB Subnet Group already exists"

# Create RDS PostgreSQL Multi-AZ instance
echo "Creating RDS PostgreSQL Multi-AZ instance..."
aws rds create-db-instance \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --db-instance-class ${DB_INSTANCE_CLASS} \
    --engine postgres \
    --engine-version "15.4" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --master-username ${DB_USER} \
    --master-user-password ${DB_PASSWORD} \
    --vpc-security-group-ids ${VPC_SECURITY_GROUP_ID} \
    --db-subnet-group-name ${DB_SUBNET_GROUP_NAME} \
    --multi-az \
    --publicly-accessible false \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "Mon:04:00-Mon:05:00" \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --enable-cloudwatch-logs-exports '["postgresql"]' \
    --deletion-protection \
    --region ${REGION}

echo "=== RDS Instance Creation Initiated ==="
echo "Check status with: aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_IDENTIFIER}"
