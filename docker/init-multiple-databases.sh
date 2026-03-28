#!/bin/bash
set -e
set -u

# Script to create multiple databases in PostgreSQL
# Place this in docker-entrypoint-initdb.d/ to run on container startup

function create_database() {
    local database=$1
    echo "Creating database: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        SELECT 'CREATE DATABASE $database'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
EOSQL
}

# Create databases for services
create_database "products_db"
create_database "orders_db"

echo "All databases created successfully!"
