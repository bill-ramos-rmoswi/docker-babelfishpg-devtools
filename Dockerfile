# ==========================================
# Babelfish for PostgreSQL DevTools Container
# ==========================================
# This multi-stage Dockerfile builds a comprehensive development environment
# for Babelfish for PostgreSQL with integrated development tools and utilities.
#
# Build Arguments:
#   BABELFISH_VERSION - Babelfish release tag (default: BABEL_5_2_0__PG_17_5)
#   JOBS - Number of parallel build jobs (default: 4)
#
# Stages:
#   1. base - Ubuntu 22.04 foundation
#   2. build-deps - Build dependencies installation
#   3. antlr-builder - ANTLR 4 compilation
#   4. postgres-builder - PostgreSQL/Babelfish compilation
#   5. bbfdump-builder - BabelfishDump utilities
#   6. runner - Final runtime image

# ==========================================
# Stage 1: Base Image
# Purpose: Common Ubuntu 22.04 foundation for all stages
# ==========================================
FROM ubuntu:22.04 AS base
ENV DEBIAN_FRONTEND=noninteractive

# ==========================================
# Stage 2: Build Dependencies
# Purpose: Install all build dependencies in a single cacheable layer
# ==========================================
FROM base AS build-deps

# Install all build dependencies at once for better layer caching
RUN apt-get update && apt-get install -y --no-install-recommends \
	# Core build tools
	build-essential \
	cmake \
	lld \
	bison \
	flex \
	gawk \
	pkg-config \
	# PostgreSQL build dependencies
	libxml2-dev \
	libxml2-utils \
	libxslt-dev \
	libssl-dev \
	libreadline-dev \
	zlib1g-dev \
	libldap2-dev \
	libpam0g-dev \
	libpq-dev \
	libossp-uuid-dev \
	uuid \
	uuid-dev \
	libicu-dev \
	libicu70 \
	icu-devtools \
	# ANTLR and Java dependencies
	openjdk-21-jre \
	g++ \
	libutfcpp-dev \
	# Additional tools
	curl \
	wget \
	git \
	gnupg \
	unzip \
	gettext \
	gnulib \
	xsltproc \
	openssl \
	python-dev-is-python3 \
	unixodbc-dev \
	net-tools \
	apt-utils \
	# PostgreSQL client tools
	postgresql-client \
	postgresql-client-common \
	postgresql-common \
	# BabelfishDump dependencies
	rpm \
	alien \
	liblz4-dev \
	libkrb5-dev \
	&& rm -rf /var/lib/apt/lists/*

# ==========================================
# Stage 3: ANTLR Builder
# Purpose: Build ANTLR 4 runtime for T-SQL parser
# ==========================================
FROM build-deps AS antlr-builder

# Build configuration
ARG JOBS=4
ARG ANTLR4_VERSION=4.13.2

# ANTLR environment variables
ENV ANTLR4_VERSION=${ANTLR4_VERSION} \
    ANTLR4_JAVA_BIN=/usr/bin/java \
    ANTLR4_RUNTIME_LIBRARIES=/usr/include/antlr4-runtime \
    ANTLR_RUNTIME=/workplace/antlr4

WORKDIR /workplace

# Download and build ANTLR C++ runtime
RUN wget http://www.antlr.org/download/antlr4-cpp-runtime-${ANTLR4_VERSION}-source.zip && \
    unzip -d ${ANTLR_RUNTIME} antlr4-cpp-runtime-${ANTLR4_VERSION}-source.zip && \
    rm antlr4-cpp-runtime-${ANTLR4_VERSION}-source.zip

WORKDIR ${ANTLR_RUNTIME}/build

RUN cmake .. \
    -DANTLR_JAR_LOCATION=/usr/local/lib/antlr-${ANTLR4_VERSION}-complete.jar \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DWITH_DEMO=True && \
    make -j ${JOBS} && \
    make install

# ==========================================
# Stage 4: PostgreSQL/Babelfish Builder
# Purpose: Build modified PostgreSQL with Babelfish extensions
# ==========================================
FROM antlr-builder AS postgres-builder

# Babelfish version configuration
ARG BABELFISH_VERSION=BABEL_5_2_0__PG_17_5
ARG JOBS=4

# Set environment variables for build
ENV BABELFISH_VERSION=${BABELFISH_VERSION} \
    BABELFISH_HOME=/opt/babelfish \
    JOBS=${JOBS}

WORKDIR /workplace

# Download Babelfish sources
RUN wget https://github.com/babelfish-for-postgresql/babelfish-for-postgresql/releases/download/${BABELFISH_VERSION}/${BABELFISH_VERSION}.tar.gz && \
    tar -xzf ${BABELFISH_VERSION}.tar.gz && \
    rm ${BABELFISH_VERSION}.tar.gz

# Set PostgreSQL source directory
ENV PG_SRC=/workplace/${BABELFISH_VERSION} \
    PG_CONFIG=/opt/babelfish/bin/pg_config

# Copy ANTLR jar for parser generation
RUN cp ${PG_SRC}/contrib/babelfishpg_tsql/antlr/thirdparty/antlr/antlr-${ANTLR4_VERSION}-complete.jar /usr/local/lib/

# Configure and build PostgreSQL with Babelfish support
WORKDIR ${PG_SRC}

RUN ./configure \
    CFLAGS="-ggdb" \
    --prefix=${BABELFISH_HOME}/ \
    --enable-debug \
    --with-ldap \
    --with-libxml \
    --with-pam \
    --with-uuid=ossp \
    --enable-nls \
    --with-libxslt \
    --with-icu \
    --with-openssl && \
    make DESTDIR=${BABELFISH_HOME}/ -j ${JOBS} 2>error.txt && \
    make install

# Build PostgreSQL contrib modules
WORKDIR ${PG_SRC}/contrib
RUN make -j ${JOBS} && make install

# Copy ANTLR runtime library
RUN cp /usr/local/lib/libantlr4-runtime.so.${ANTLR4_VERSION} ${BABELFISH_HOME}/lib

# Build ANTLR parser for T-SQL
WORKDIR ${PG_SRC}/contrib/babelfishpg_tsql/antlr
RUN cmake -Wno-dev . && make all

# Build Babelfish extension modules
WORKDIR ${PG_SRC}/contrib
RUN for module in babelfishpg_common babelfishpg_money babelfishpg_tds babelfishpg_tsql; do \
        echo "Building $module..." && \
        cd $module && \
        make -j ${JOBS} && \
        make PG_CONFIG=${PG_CONFIG} install && \
        cd ..; \
    done

# ==========================================
# Stage 5: BabelfishDump Builder
# Purpose: Build BabelfishDump backup utilities
# ==========================================
FROM postgres-builder AS bbfdump-builder

ARG BABELFISH_VERSION=BABEL_5_2_0__PG_17_5
ARG JOBS=4

WORKDIR /workplace

# Clone and build BabelfishDump utilities
RUN git clone https://github.com/babelfish-for-postgresql/postgresql_modified_for_babelfish.git && \
    cd postgresql_modified_for_babelfish && \
    git checkout ${BABELFISH_VERSION} && \
    make rpm NODEPS=1 && \
    cd build && \
    alien -i BabelfishDump*.rpm && \
    rm -f *.rpm

# ==========================================
# Stage 6: Final Runtime Image
# Purpose: Minimal runtime with all necessary components
# ==========================================
FROM base AS runner

# Set environment for runtime
ENV LC_ALL=C \
    LANG=C \
    LANGUAGE=C \
    BABELFISH_HOME=/opt/babelfish \
    POSTGRES_USER_HOME=/var/lib/babelfish \
    BABELFISH_DATA=/var/lib/babelfish/data \
    PATH=/opt/babelfish/bin:$PATH

# Create necessary directories
RUN mkdir -p ${BABELFISH_HOME} ${POSTGRES_USER_HOME} ${BABELFISH_DATA} /var/lib/babelfish/bbf_backups

# Copy compiled binaries from builder stages
COPY --from=bbfdump-builder ${BABELFISH_HOME} ${BABELFISH_HOME}
COPY --from=bbfdump-builder /usr/bin/bbf_dump /usr/bin/bbf_dumpall /usr/bin/

# Install runtime dependencies (optimized for size)
RUN apt-get update && apt-get install -y --no-install-recommends \
	# PostgreSQL runtime libraries
	libssl3 \
	openssl \
	libldap-2.5-0 \
	libxml2 \
	libpam0g \
	uuid \
	libossp-uuid16 \
	libxslt1.1 \
	libicu70 \
	libpq5 \
	unixodbc \
	# PostgreSQL client tools
	postgresql-client \
	postgresql-client-common \
	postgresql-common \
	# System utilities
	sudo \
	dos2unix \
	curl \
	ca-certificates \
	gnupg \
	# Required for some scripts
	git \
	build-essential \
	alien \
	&& rm -rf /var/lib/apt/lists/*

# Install Node.js and Claude CLI for AI-assisted development
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    npm install -g @anthropic-ai/claude-code && \
    claude migrate-installer || true && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH server for remote access
RUN apt-get update && \
    apt-get install -y openssh-server && \
    mkdir -p /var/run/sshd && \
    echo 'root:postgres' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    rm -rf /var/lib/apt/lists/*

# Install Microsoft SQL Server command line tools (Issue #14)
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 \
    mssql-tools18 \
    && rm -rf /var/lib/apt/lists/* && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/profile.d/mssql.sh && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bash.bashrc

# Copy and prepare helper scripts
COPY backup_babelfish.sh restore_babelfish.sh pg_env.sh /tmp/
RUN dos2unix /tmp/*.sh && \
    mv /tmp/backup_babelfish.sh /tmp/restore_babelfish.sh /usr/bin/ && \
    mv /tmp/pg_env.sh /etc/profile.d/ && \
    chmod +x /usr/bin/backup_babelfish.sh /usr/bin/restore_babelfish.sh /etc/profile.d/pg_env.sh

# Set up postgres user permissions
RUN chown -R postgres:postgres ${BABELFISH_HOME} ${POSTGRES_USER_HOME} && \
    echo "postgres ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Ensure Claude CLI is accessible to postgres user
RUN if [ -d /root/.local/share/claude ]; then \
        cp -r /root/.local/share/claude /usr/local/share/claude && \
        chmod -R 755 /usr/local/share/claude; \
    fi

# Define data volume for persistence
VOLUME ${BABELFISH_DATA}

# Expose network ports
EXPOSE 22 1433 5432

# Copy and set entry point script
COPY start.sh /
RUN chmod +x /start.sh

# Container starts as root to handle permissions
# start.sh will switch to postgres user after initialization
ENTRYPOINT ["/start.sh"]