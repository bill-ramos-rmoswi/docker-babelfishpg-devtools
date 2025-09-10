#!/bin/bash
# PostgreSQL environment variables

# Set locale to avoid warnings
export LC_ALL=C
export LANG=C
export LANGUAGE=C
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=babelfish_db
export PGUSER=babelfish_admin
export PGPASSWORD=secret_password
export PGDATA=/var/lib/babelfish/data
export PATH=/opt/babelfish/bin:$PATH
export PGSSLMODE=require  # Enable SSL by default for secure connections
