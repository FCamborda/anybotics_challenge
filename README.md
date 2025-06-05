# Deployment environment challenge

This project automates the provisioning of a simulated environment and deploys an Nginx server that acts as a reverse proxy to an `http-https-echo` service.
The entire process is orchestrated by a single `start.sh` script which utilizes Docker, Docker Compose, and Ansible.

## Directory structure

```
├── ansible
│   ├── echo-compose.yaml         # Compose file 
│   ├── inventory.ini             # Ansible inventory configuration
│   ├── nginx.conf                # Nginx configuration for reverse-proxy
│   ├── ansible.cfg               # Ansible user configuration
│   └── deployment.yaml           # Ansible playbook to provision and deploy applications
├── docker-compose.yml            # Container configuration
├── Dockerfile.a                  # Container A definition (controller)
├── Dockerfile.b                  # Container B definition
└── start.sh                      # Entry script
```

## Core Components:

* **Host:** The primary machine running Docker Desktop, which hosts the entire simulated environment.
* **`instance_a` (Docker Container on Host):**
    * Acts as the Ansible control node.
    * Initiates deployments to `instance_b`'s Docker daemon and the Host's Docker daemon.
    * Has the Ansible project files and SSH private key mounted into it.
* **`instance_b` (Docker Container on Host):**
    * Hosts its own isolated Docker daemon (Docker-in-Docker).
    * The `http-echo-b` service runs within this internal Docker environment.
* **`http-echo-b` (Docker Container inside `instance_b`'s Docker):**
    * Runs the `mendhak/http-https-echo` image.
    * Deployed via `echo-compose.yaml` orchestrated by Ansible running on `instance_a`.
* **`nginx_ansible_direct_test` (Docker Container on Host):**
    * An Nginx server running directly on the Host's Docker daemon.
    * Controlled by Ansible running on `instance_a` (via a mounted Docker socket).
    * Configured to proxy requests to `http-echo-b`.
* **`provisioning_network_global` (Docker Network on Host):**
    * A custom Docker bridge network on the Host.
    * Connects `instance_a`, `instance_b`, and `nginx_ansible_direct_test`, enabling them to communicate by service name.

## Workflow

**Pre-step needed:**
* The variables `HOST_GID` and `HOST_UID` should be set (e.g. `export HOST_GID=$(id -g)` and `export_HOST_UID=$(id -u)`)
* Before running the scripts, the user should adapt the local path `/Users/franco/git/anybotics_challenge/ansible/nginx_host_docker_configs/nginx.conf` to their local full path of `./ansible/nginx.conf`. For an explanation check the section Limitations below.

1.  The user executes `./start.sh` on the Host. The cwd should be the repository root.
2.  The script generates an SSH key pair (`~/.ssh/ansible_key` and `~/.ssh/ansible_key.pub`) if it doesn't already exist, for SSH access into the instances.
3.  The top-level `docker-compose.yml` is invoked by `start.sh` to build and start `instance_a` and `instance_b` containers. These containers are connected to the `provisioning_network_global` on the Host.
4.  `start.sh` then executes the main Ansible playbook (`ansible/working_playbook.yaml`) *from within the `instance_a` container*.
5.  The Ansible playbook performs the following:
    * Installs Docker and its dependencies on both `instance_a` (if needed for Ansible modules) and `instance_b`.
    * Configures `instance_b`'s internal Docker daemon to listen on a TCP socket (e.g., `tcp://0.0.0.0:2375`) for remote commands from `instance_a`.
    * Ensures a network (e.g., `provisioning_network_global`) exists *inside `instance_b`'s Docker environment* for the `http-echo-b` service (if `echo-compose.yaml` declares it as external).
    * Deploys `http-echo-b` to `instance_b`'s Docker daemon using the `ansible/echo-compose.yaml` file.
    * Copies the `nginx.conf` to a location on `instance_a` that is shared/mounted from the Host (e.g., `/home/ansible/ansible_project/nginx_host_docker_configs/nginx.conf` inside `instance_a` maps to `/Users/your_user/.../nginx_host_docker_configs/nginx.conf` on the host).
    * Deploys the `nginx_ansible_direct_test` container to the Host's Docker daemon, using the mounted `nginx.conf`.
6.  The setup is complete, with Nginx on the Host proxying requests from `localhost:80` to the `http-echo-b` service running within `instance_b`.


## Best practices

* **Docker & General Containerization:**
    * **Named Containers:** (e.g., `instance_a`, `nginx_ansible_direct_test`) for easier reference.
    * **Custom Networks:** (e.g., `provisioning_network_global`) for controlled communication.
    * **Explicit Port Mappings:** Clearly defined for all exposed services.
    * **Read-Only Volumes:** (e.g., `nginx.conf` mounted as `:ro`) to enhance security.
    * **Use of Official Images:** (e.g., `nginx:latest`, `mendhak/http-https-echo:latest`).
* **Docker Compose (for `echo-compose.yaml` and top-level `docker-compose.yml`):**
    * **Service Definitions:** Clear separation of services.
    * **Declarative Configuration:** Defining the desired state of services, networks, and volumes.
    * **Environment Isolation:** `instance_b` running its own Docker daemon provides a level of isolation.
* **Ansible for Docker Provisioning & Deployment:**
    * **Idempotency:** Efforts made in Ansible tasks to be idempotent (e.g., `|| true` in shell commands for creation)
    * **Modularity:** Using Ansible modules for specific tasks where possible (e.g., `ansible.builtin.copy`, `community.docker.docker_container`).
    * **Configuration Management:** Managing `daemon.json` and `nginx.conf` through Ansible.
    * **Orchestration:** Managing multi-step, multi-host deployments.

## Testing

* The Ansible playbook includes a URI check (`Test Nginx proxying to http-echo`) as a basic end-to-end test of the deployed services.


## Limitations and further improvements

* As seen in the core components section, the Docker-in-Docker setup does not use the Docker daemon of `instance_a` to deploy the nginx container as it's flaky, but instead relies in the host's Docker daemon
* Although exhaustively troubleshooted, the Ansible tasks do not behave well when using the docker compose plugin and external networks. Thus, the deployment of the nginx container is done with bare docker commands instead
* The latter is inconsitent with the deployment of the https-http-echo container, which uses docker-compose
* Furthermore, the SSH keys setup in the host machine does not behave well when working with Docker-in-Docker deployments. Hence, the Ansible configuration should not pass `ssh_args = -o IdentityFilePermissions=0600`
* In a production setting, specific versions should be used for the docker images
* The Docker TCP socket on `instance_b` is exposed without TLS for simplicity. A true production-grade deployment should address this.
* In order to overcome the quirks of a Docker-in-Docker setup, `privileged:true` had to be used in order tu grant nested containers access to the host Docker socket. This should be reviewed in production.
* The user entry-point `start.sh` should ideally be more resilient and include full tear-down options for a better user-experience
* For observability, the app containers could forward their logs to a centralized logging aggregation system
* Similarly, the `http-https-echo` and `nginx` services should provide metrics like http requests, active connections, etc