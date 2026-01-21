#!/bin/bash
# PostgreSQL initialization script
# This script runs automatically when PostgreSQL first initializes the data directory
# It is executed by the postgres image's entrypoint script from /docker-entrypoint-initdb.d/

set -e

echo "Initializing PostgreSQL databases and permissions..."

# Create hive database and grant privileges
psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    -- Create "hive" database if it doesn't exist
    SELECT 'CREATE DATABASE hive'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'hive')\gexec
    
    -- Grant privileges on the hive database
    GRANT ALL PRIVILEGES ON DATABASE hive TO "$POSTGRES_USER";
    
    -- Grant schema permissions in metastore database
    GRANT ALL ON SCHEMA public TO "$POSTGRES_USER";
    GRANT CREATE ON SCHEMA public TO "$POSTGRES_USER";
    GRANT USAGE ON SCHEMA public TO "$POSTGRES_USER";
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$POSTGRES_USER";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$POSTGRES_USER";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "$POSTGRES_USER";
    
    -- Grant privileges on existing objects
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$POSTGRES_USER";
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$POSTGRES_USER";
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "$POSTGRES_USER";
    
    -- Make the user the owner of the public schema
    ALTER SCHEMA public OWNER TO "$POSTGRES_USER";
EOSQL

# Set permissions in the hive database
psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" -d hive <<-EOSQL
    -- Grant schema permissions in hive database
    GRANT ALL ON SCHEMA public TO "$POSTGRES_USER";
    GRANT CREATE ON SCHEMA public TO "$POSTGRES_USER";
    GRANT USAGE ON SCHEMA public TO "$POSTGRES_USER";
    ALTER SCHEMA public OWNER TO "$POSTGRES_USER";
EOSQL

echo "PostgreSQL initialization complete."
