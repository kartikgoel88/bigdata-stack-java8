#!/bin/bash
set -e

echo "Initializing PostgreSQL databases..."

# Wait for PostgreSQL to be ready
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
    echo "Waiting for PostgreSQL to start..."
    sleep 1
done

# The POSTGRES_USER and POSTGRES_DB are already created by the postgres image
# But we need to create a "hive" database as well (for default connections)
# and ensure proper permissions are set

# Connect as the POSTGRES_USER (which has superuser privileges when set as POSTGRES_USER)
psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    -- Create "hive" database if it doesn't exist (for default user connections)
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
    -- Grant privileges on existing objects (ignore errors if objects don't exist)
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$POSTGRES_USER";
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$POSTGRES_USER";
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "$POSTGRES_USER";
    -- Make the user the owner of the public schema
    ALTER SCHEMA public OWNER TO "$POSTGRES_USER";
EOSQL

# Also set permissions in the hive database
psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" -d hive <<-EOSQL
    -- Grant schema permissions in hive database
    GRANT ALL ON SCHEMA public TO "$POSTGRES_USER";
    GRANT CREATE ON SCHEMA public TO "$POSTGRES_USER";
    GRANT USAGE ON SCHEMA public TO "$POSTGRES_USER";
    ALTER SCHEMA public OWNER TO "$POSTGRES_USER";
EOSQL

echo "PostgreSQL initialization complete."

