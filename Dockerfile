# syntax=docker/dockerfile:1

ARG BASE_IMAGE

FROM ${BASE_IMAGE}

ARG POSTGIS_VERSION
ARG POSTGIS_SHA256
ARG TIMESCALEDB_VERSION


LABEL maintainer="Creowave Oy"

# Stop on errors and print commands
RUN set -eux

###########
# POSTGIS #
###########

# Install dependencies
RUN apk add --no-cache --virtual .postgis-fetch-deps \
  ca-certificates \
  openssl \
  tar \
  && apk add --no-cache --virtual .postgis-build-deps \
  gdal-dev \
  geos-dev \
  proj-dev \
  proj-util \
  sfcgal-dev \
  clang \
  llvm \
  autoconf \
  automake \
  cunit-dev \
  file \
  g++ \
  gcc \
  gettext-dev \
  git \
  json-c-dev \
  libtool \
  libxml2-dev \
  make \
  pcre2-dev \
  perl \
  protobuf-c-dev \
  && apk add --no-cache --virtual .postgis-run-deps \
  gdal \
  geos \
  proj \
  sfcgal \
  json-c \
  libstdc++ \
  pcre2 \
  protobuf-c \
  ca-certificates

# Create symlinks matching the LLVM paths hardcoded in PostgreSQL's PGXS build system
RUN PGXS_CLANG=$(grep '^CLANG' /usr/local/lib/postgresql/pgxs/src/Makefile.global | sed 's/.*= *//') \
  && PGXS_LLVM_BINPATH=$(grep '^LLVM_BINPATH' /usr/local/lib/postgresql/pgxs/src/Makefile.global | sed 's/.*= *//') \
  && echo "PGXS expects CLANG=${PGXS_CLANG}, LLVM_BINPATH=${PGXS_LLVM_BINPATH}" \
  && ln -sf /usr/bin/clang "/usr/bin/${PGXS_CLANG}" \
  && mkdir -p "${PGXS_LLVM_BINPATH}" \
  && ln -sf /usr/bin/llvm-lto "${PGXS_LLVM_BINPATH}/llvm-lto"

# Download, verify and extract PostGIS source code
RUN wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz" \
  && echo "${POSTGIS_SHA256} *postgis.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/postgis \
  && tar \
  --extract \
  --file postgis.tar.gz \
  --directory /usr/src/postgis \
  --strip-components 1 \
  && rm postgis.tar.gz

# Build PostGIS
RUN cd /usr/src/postgis \
  && gettextize \
  && ./autogen.sh \
  && ./configure \
  && make -j$(nproc) \
  && make install

# Cleanup
RUN rm -rf /usr/src/postgis \
  && apk del .postgis-fetch-deps .postgis-build-deps

###############
# TIMESCALEDB #
###############

# Install dependencies
RUN apk add --no-cache --virtual .timescaledb-fetch-deps \
  git \
  && apk add --no-cache --virtual .timescaledb-build-deps \
  openssl-dev \
  icu-dev \
  clang \
  gcc \
  cmake \
  make

# Clone TimescaleDB source code
RUN mkdir -p /usr/src/timescaledb \
  && git clone --depth 1 --branch "${TIMESCALEDB_VERSION}" https://github.com/timescale/timescaledb /usr/src/timescaledb

# Build and enable TimescaleDB
RUN cd /usr/src/timescaledb \
  && ./bootstrap \
  && cd build \
  && make \
  && make install \
  && sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/local/share/postgresql/postgresql.conf.sample

# Cleanup
RUN rm -rf /usr/src/timescaledb \
  && apk del .timescaledb-fetch-deps .timescaledb-build-deps
