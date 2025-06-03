# Creowave PostgreSQL Docker Image

A multi-architecture (amd64, arm64) Docker image for PostgreSQL with PostGIS and TimescaleDB extensions, based on the official Alpine PostgreSQL image.

## Usage

Before running the image, you need to create an initialization script to create your database and enable the required extensions. For example, create a Bash script named `0001-init.sh` inside a directory called `initdb.d` with the following content:

```bash
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<- EOSQL
  CREATE DATABASE <db-name>;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="<db-name>" <<- EOSQL
  CREATE EXTENSION postgis;
  CREATE EXTENSION timescaledb;
EOSQL
```

- Replace `<db-name>` with the desired database name.
- Make sure the script is executable: `chmod +x initdb.d/0001-init.sh`
- You can add additional scripts to the `initdb.d` directory as needed. All executable scripts in this directory will be run in order by the PostgreSQL Docker entrypoint.

### Running with Docker or Podman

You can run the image directly with Docker or Podman (by replacing `docker` with `podman`):

```console
docker run \
  --name postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -v postgresdata:/var/lib/postgresql/data \
  -v ./initdb.d:/docker-entrypoint-initdb.d \
  creowave/postgres:<version>
```

- Replace `<version>` with the desired image version.
- Ensure the `initdb.d` path refers to the directory containing your initialization scripts.

### Running with Docker Compose or Podman Compose

Below is an example `docker-compose.yml` file for running the image with persistent storage and initialization scripts.

```yaml
services:
  postgres:
    image: creowave/postgres:<version>
    restart: always
    ports:
      - 5432:5432
    volumes:
      - postgresdata:/var/lib/postgresql/data
      - ./initdb.d:/docker-entrypoint-initdb.d
    environment:
      - POSTGRES_PASSWORD=postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 5s
      retries: 10
volumes:
  postgresdata:
```

- Replace `<version>` with the desired image version.
- Ensure the `initdb.d` path refers to the directory containing your initialization scripts.

Start the service with Docker or Podman:

```sh
docker compose up -d
# or
podman-compose up -d
```

### Verifying extensions

After starting the container, verify that both extensions are present:

```sh
psql -d "postgres://postgres:postgres@localhost/<db-name>"

# In the psql console:
\dx
```

## Building the image locally

To build the Docker image locally, you must provide the required build arguments as environment variables. The recommended way is to use the provided `.env` file and load it automatically with [direnv](https://direnv.net/).

To build the image, run the following command. To use Podman, replace `docker` with `podman`.

```console
docker build \
  --build-arg BASE_IMAGE \
  --build-arg POSTGIS_VERSION \
  --build-arg POSTGIS_SHA256 \
  --build-arg TIMESCALEDB_VERSION \
  -t creowave/postgres:local .
```

You can then run the image using the instructions above, replacing `<version>` with `local`.

## Versioning & Releases

- Images are built and published automatically by GitHub Actions when a tag starting with `v` is pushed (e.g., `v17.5.0`).
- The published Docker image tag will match the tag name, but without the leading `v`.
- The major and minor part of the version number match the PostgreSQL version number, while the patch represents an iteration of the image.
- Note: This versioning scheme is not strictly SemVer, but it should be safe to treat it as SemVer for most use cases.
