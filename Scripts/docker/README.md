# Docker Utility Scripts 🐳

Scripts to help manage Docker environments.

---

## `list-docker-info.sh`

Lists running containers and Docker images present on the system.

### Purpose

Provides a quick overview of the current Docker state, including running container names, images, status, ports, and available images with their tags and sizes.

### Usage

```bash
./list-docker-info.sh
```

### Dependencies

* `docker`: Must be installed and the user running the script needs permission to interact with the Docker daemon (usually by being in the `docker` group).

### Example Output

```
ℹ️  🐳ℹ️ Gathering Docker information...

--- Running Containers ---
NAMES         IMAGE                           STATUS         PORTS
my-nginx      nginx:latest                    Up 2 hours     0.0.0.0:80->80/tcp
my-app        my-custom-app:v1.2              Up 3 days      0.0.0.0:8080->8080/tcp

--- Docker Images ---
REPOSITORY          TAG                 SIZE
nginx               latest              142MB
my-custom-app       v1.2                450MB
ubuntu              latest              77.8MB

✅ ✨ Docker information retrieval finished!
```

---

## `update-docker-compose-app.sh`

Pulls the latest images and restarts a Docker Compose application stack in a specified directory.

### ⚠️ WARNING ⚠️

This script restarts containers based on potentially newer images. **This can break your application** if the new images have compatibility issues or breaking changes. **Use with extreme caution.** Always ensure you have backups or a rollback plan before running this on critical applications.

### Purpose

Automates the common workflow of updating a Docker Compose based application: pull latest images, then restart the stack with `docker-compose up -d`.

### Usage

Requires the path to the directory containing the `docker-compose.yml` (or `.yaml`) file as an argument.

```bash
./update-docker-compose-app.sh /path/to/your/compose-app-directory
```

The script will ask for confirmation before proceeding.

### Dependencies

* `docker`: Must be installed and running.
* `docker-compose`: Must be installed.
* User permissions to interact with Docker and Docker Compose.
* A valid `docker-compose.yml` or `docker-compose.yaml` file in the target directory.

### Example

```bash
# Update the 'my-cool-app' stack located in /srv/docker/my-cool-app
./update-docker-compose-app.sh /srv/docker/my-cool-app

# Script output will show warnings, ask for confirmation,
# then show output from 'docker-compose pull' and 'docker-compose up -d'.
```

---
