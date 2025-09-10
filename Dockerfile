FROM ubuntu:22.04 AS base

# Build stage
FROM base AS builder

# Specify babelfish version by using a tag from:
# https://github.com/babelfish-for-postgresql/babelfish-for-postgresql/tags
ARG BABELFISH_VERSION=BABEL_5_2_0__PG_17_5

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt update && apt install -y --no-install-recommends\
	build-essential flex libxml2-dev libxml2-utils\
	libxslt-dev libssl-dev libreadline-dev zlib1g-dev\
	libldap2-dev libpam0g-dev gettext uuid uuid-dev\
	cmake lld apt-utils libossp-uuid-dev gnulib bison\
	xsltproc icu-devtools libicu70\
	libicu-dev gawk\
	curl openjdk-21-jre openssl\
	g++ libssl-dev python-dev-is-python3 libpq-dev\
	pkg-config libutfcpp-dev\
	gnupg unixodbc-dev net-tools unzip wget\
	postgresql-client postgresql-client-common postgresql-common git

# Download babelfish sources
WORKDIR /workplace

ENV BABELFISH_REPO=babelfish-for-postgresql/babelfish-for-postgresql
ENV BABELFISH_URL=https://github.com/${BABELFISH_REPO}
ENV BABELFISH_TAG=${BABELFISH_VERSION}
ENV BABELFISH_FILE=${BABELFISH_VERSION}.tar.gz

RUN wget ${BABELFISH_URL}/releases/download/${BABELFISH_TAG}/${BABELFISH_FILE}
RUN tar -xvzf ${BABELFISH_FILE}

# Set environment variables
ENV JOBS=4
ENV BABELFISH_HOME=/opt/babelfish
ENV PG_CONFIG=${BABELFISH_HOME}/bin/pg_config
ENV PG_SRC=/workplace/${BABELFISH_VERSION}

WORKDIR ${PG_SRC}

ENV PG_CONFIG=${BABELFISH_HOME}/bin/pg_config

# Compile ANTLR 4
ENV ANTLR4_VERSION=4.13.2
ENV ANTLR4_JAVA_BIN=/usr/bin/java
ENV ANTLR4_RUNTIME_LIBRARIES=/usr/include/antlr4-runtime
ENV ANTLR_FILE=antlr-${ANTLR4_VERSION}-complete.jar
ENV ANTLR_EXECUTABLE=/usr/local/lib/${ANTLR_FILE}
ENV ANTLR_CONTRIB=${PG_SRC}/contrib/babelfishpg_tsql/antlr/thirdparty/antlr
ENV ANTLR_RUNTIME=/workplace/antlr4

RUN cp ${ANTLR_CONTRIB}/${ANTLR_FILE} /usr/local/lib

WORKDIR /workplace

ENV ANTLR_DOWNLOAD=http://www.antlr.org/download
ENV ANTLR_CPP_SOURCE=antlr4-cpp-runtime-${ANTLR4_VERSION}-source.zip

RUN wget ${ANTLR_DOWNLOAD}/${ANTLR_CPP_SOURCE}
RUN unzip -d ${ANTLR_RUNTIME} ${ANTLR_CPP_SOURCE}

WORKDIR ${ANTLR_RUNTIME}/build

RUN cmake .. -D\
	ANTLR_JAR_LOCATION=${ANTLR_EXECUTABLE}\
	-DCMAKE_INSTALL_PREFIX=/usr/local -DWITH_DEMO=True
RUN make -j ${JOBS} && make install

# Build modified PostgreSQL for Babelfish
WORKDIR ${PG_SRC}

RUN ./configure CFLAGS="-ggdb"\
	--prefix=${BABELFISH_HOME}/\
	--enable-debug\
	--with-ldap\
	--with-libxml\
	--with-pam\
	--with-uuid=ossp\
	--enable-nls\
	--with-libxslt\
	--with-icu\
	--with-openssl
					
RUN make DESTDIR=${BABELFISH_HOME}/ -j ${JOBS} 2>error.txt && make install

WORKDIR ${PG_SRC}/contrib

RUN make -j ${JOBS} && make install

# Compile the ANTLR parser generator
RUN cp /usr/local/lib/libantlr4-runtime.so.${ANTLR4_VERSION}\
	${BABELFISH_HOME}/lib
					 
WORKDIR ${PG_SRC}/contrib/babelfishpg_tsql/antlr 
RUN cmake -Wno-dev .
RUN make all

# Compile the contrib modules and build Babelfish
WORKDIR ${PG_SRC}/contrib/babelfishpg_common
RUN make -j ${JOBS} && make PG_CONFIG=${PG_CONFIG} install

WORKDIR ${PG_SRC}/contrib/babelfishpg_money
RUN make -j ${JOBS} && make PG_CONFIG=${PG_CONFIG} install

WORKDIR ${PG_SRC}/contrib/babelfishpg_tds
RUN make -j ${JOBS} && make PG_CONFIG=${PG_CONFIG} install

WORKDIR ${PG_SRC}/contrib/babelfishpg_tsql
RUN make -j ${JOBS} && make PG_CONFIG=${PG_CONFIG} install

# Build and install BabelfishDump utilities
WORKDIR /workplace

# Clone the postgresql_modified_for_babelfish repository
RUN git clone https://github.com/babelfish-for-postgresql/postgresql_modified_for_babelfish.git
WORKDIR /workplace/postgresql_modified_for_babelfish
# Checkout the same version as Babelfish
RUN git checkout ${BABELFISH_TAG}

# Install additional build dependencies for BabelfishDump
RUN apt-get update && apt-get install -y \
    rpm \

	liblz4-dev \
    libicu-dev \
    libxml2-dev \
    libssl-dev \
    uuid-dev \
    libkrb5-dev \
    libpam-dev \
    alien \
    && rm -rf /var/lib/apt/lists/*

# Build BabelfishDump RPM
RUN make rpm NODEPS=1

# Install the built RPM using alien (converts and installs RPM to DEB)
RUN cd build && \
    alien -i BabelfishDump*.rpm && \
    rm -f *.rpm

# Run stage
FROM base AS runner
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C
ENV LANG=C
ENV LANGUAGE=C
ENV BABELFISH_HOME=/opt/babelfish
ENV POSTGRES_USER_HOME=/var/lib/babelfish

# Install dos2unix first
RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/*

# Copy binaries and scripts to run stage
WORKDIR ${BABELFISH_HOME}
COPY --from=builder ${BABELFISH_HOME} .
COPY --from=builder /usr/bin/bbf_dump /usr/bin/
COPY --from=builder /usr/bin/bbf_dumpall /usr/bin/

# Copy and prepare scripts
COPY backup_babelfish.sh restore_babelfish.sh pg_env.sh /tmp/
RUN dos2unix /tmp/backup_babelfish.sh /tmp/restore_babelfish.sh /tmp/pg_env.sh && \
    mv /tmp/backup_babelfish.sh /tmp/restore_babelfish.sh /usr/bin/ && \
    mv /tmp/pg_env.sh /etc/profile.d/ && \
    chmod +x /usr/bin/backup_babelfish.sh /usr/bin/restore_babelfish.sh /etc/profile.d/pg_env.sh

# Create backup directory structure
RUN mkdir -p /var/lib/babelfish/bbf_backups

# Install runtime dependencies
RUN apt update && apt install -y --no-install-recommends\
	libssl3 openssl libldap-2.5-0 libxml2 libpam0g uuid libossp-uuid16\
	libxslt1.1 libicu70 libpq5 unixodbc sudo postgresql-client\
	postgresql-client-common postgresql-common git build-essential alien\
	dos2unix

# BabelfishDump utilities are already installed from the builder stage

# Enable data volume
ENV BABELFISH_DATA=${POSTGRES_USER_HOME}/data
RUN mkdir -p ${BABELFISH_DATA}
VOLUME ${BABELFISH_DATA}

# Install and configure SSH
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:postgres' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Set up postgres user directories
RUN mkdir -p ${POSTGRES_USER_HOME} && \
    chown -R postgres:postgres ${BABELFISH_HOME} && \
    chown -R postgres:postgres ${POSTGRES_USER_HOME}
RUN echo "postgres ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Expose SSH port
EXPOSE 22

# Change to postgres user
USER postgres

# Expose ports
# TDS (SQL Server protocol) port
EXPOSE 1433
# PostgreSQL native port
EXPOSE 5432

# Set entry point
COPY start.sh /
ENTRYPOINT [ "/start.sh" ]
