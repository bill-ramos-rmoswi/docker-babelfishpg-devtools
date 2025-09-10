#!/bin/sh
BABELFISH_HOME=/opt/babelfish
BABELFISH_DATA=/var/lib/babelfish/data
BABELFISH_BIN=${BABELFISH_HOME}/bin

# Set up environment
export PATH=$PATH:${BABELFISH_BIN}
export PGDATA=${BABELFISH_DATA}

# Fix permissions on data directory (running as root initially)
if [ "$(id -u)" = "0" ]; then
    echo "Fixing permissions on data directory..."
    chown -R postgres:postgres ${BABELFISH_DATA}
    chmod 700 ${BABELFISH_DATA}
fi

# TODO - Add BabelfishDump verification when it's working
# Verify PostgreSQL tools are available
if ! command -v psql >/dev/null 2>&1; then
    echo "Error: Required PostgreSQL tools not found in PATH"
    echo "PATH=$PATH"
    exit 1
fi

# Set default argument values
USERNAME=babelfish_admin
PASSWORD=secret_password
DATABASE=babelfish_db
MIGRATION_MODE=multi-db

# Populate argument values from command
while getopts u:p:d:m: flag; do
	case "${flag}" in
		u) USERNAME=${OPTARG};;
		p) PASSWORD=${OPTARG};;
		d) DATABASE=${OPTARG};;
		m) MIGRATION_MODE=${OPTARG};;
	esac
done

# Initialize database cluster if it does not exist
if [ ! -f ${BABELFISH_DATA}/postgresql.conf ]; then
	echo "Initializing database cluster..."
	# Run initdb as postgres user
	su - postgres -c "${BABELFISH_BIN}/initdb -D ${BABELFISH_DATA}/ -E 'UTF8'"
	cat <<- EOF >> ${BABELFISH_DATA}/pg_hba.conf
		# Allow all connections
		hostssl	all		all		0.0.0.0/0		md5
		hostssl	all		all		::0/0				md5
	EOF
	cat <<- EOF >> ${BABELFISH_DATA}/postgresql.conf
		#------------------------------------------------------------------------------
		# BABELFISH RELATED OPTIONS
		# These are going to step over previous duplicated variables.
		#------------------------------------------------------------------------------
		listen_addresses = '*'
		allow_system_table_mods = on
		shared_preload_libraries = 'babelfishpg_tds'
		babelfishpg_tds.listen_addresses = '*'
		ssl = on

		#------------------------------------------------------------------------------
		# LOGGING OPTIONS
		# Aurora PostgreSQL-compatible logging setup
		#------------------------------------------------------------------------------
		logging_collector = on
		log_directory = 'log'
		log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
		log_rotation_age = 1d
		log_rotation_size = 100MB
		log_truncate_on_rotation = on
		log_min_messages = info
		log_min_error_statement = error
		log_connections = on
		log_disconnections = on
		log_duration = off
		log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
		log_statement = 'all'
		log_timezone = 'UTC'
	EOF

	# Create log directory with proper permissions
	mkdir -p ${BABELFISH_DATA}/log
	chown postgres:postgres ${BABELFISH_DATA}/log
	chmod 700 ${BABELFISH_DATA}/log

	# Generate self-signed certificate
	cd ${BABELFISH_DATA}
	openssl req -new -x509 -days 365 -nodes -text -out server.crt \
		-keyout server.key -subj "/CN=localhost"
	chmod og-rwx server.key
	chown postgres:postgres server.key server.crt
	# Start PostgreSQL as postgres user
	su - postgres -c "${BABELFISH_BIN}/pg_ctl -D ${BABELFISH_DATA}/ start"
	${BABELFISH_BIN}/psql -c "CREATE USER ${USERNAME} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '${PASSWORD}' INHERIT;" \
		-c "DROP DATABASE IF EXISTS ${DATABASE};" \
		-c "CREATE DATABASE ${DATABASE} OWNER ${USERNAME};" \
		-c "\c ${DATABASE}" \
		-c "CREATE EXTENSION IF NOT EXISTS \"babelfishpg_tds\" CASCADE;" \
		-c "GRANT ALL ON SCHEMA sys to ${USERNAME};" \
		-c "ALTER USER ${USERNAME} CREATEDB;" \
		-c "ALTER SYSTEM SET babelfishpg_tsql.database_name = '${DATABASE}';" \
		-c "SELECT pg_reload_conf();" \
		-c "ALTER DATABASE ${DATABASE} SET babelfishpg_tsql.migration_mode = 'multi-db';" \
		-c "SELECT pg_reload_conf();" \
		-c "CALL SYS.INITIALIZE_BABELFISH('${USERNAME}');"
	su - postgres -c "${BABELFISH_BIN}/pg_ctl -D ${BABELFISH_DATA}/ stop"
fi

# Start SSH daemon in the background (if running as root)
if [ "$(id -u)" = "0" ]; then
    /usr/sbin/sshd
fi

# Start postgres engine as postgres user
if [ "$(id -u)" = "0" ]; then
    exec su - postgres -c "${BABELFISH_BIN}/postgres -D ${BABELFISH_DATA}/ -i"
else
    exec ${BABELFISH_BIN}/postgres -D ${BABELFISH_DATA}/ -i
fi
