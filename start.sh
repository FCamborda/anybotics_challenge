#!/bin/bash

set -eu
set -o pipefail

# Configuration
SSH_KEY_NAME="ansible_key"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
PLAYBOOK_NAME="deployment.yaml"
INVENTORY_NAME="inventory.ini"

echo "--- Starting Automated Provisioning and Deployment ---"

# --- 1. Generate SSH Key Pair (if it doesn't exist) ---
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Generating SSH key pair at $SSH_KEY_PATH..."
    # -N "" for no passphrase
    # -f specifies the output file
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
    echo "SSH key generation complete."
else
    echo "SSH key pair already exists at $SSH_KEY_PATH. Skipping generation."
fi

# Ensure private key has correct, restrictive permissions
echo "Setting permissions for private key: $SSH_KEY_PATH"
chmod 600 "$SSH_KEY_PATH"
# Ensure public key is readable
if [ -f "${SSH_KEY_PATH}.pub" ]; then
    chmod 644 "${SSH_KEY_PATH}.pub"
fi
echo ""

# --- 2. Build and Start Docker Environment (instance_a, instance_b) ---
echo "Building and starting Docker environment (instance_a, instance_b)..."
# Assuming docker-compose.yml is in the current directory
if [ ! -f "docker-compose.yaml" ]; then
    echo "ERROR: docker-compose.yaml not found in the current directory!"
    exit 1
fi
docker compose up --build -d
echo "Docker environment started."
echo ""

# --- 3. Wait for SSH on instances to be ready ---
# (Ansible will also retry, but a small wait here can be good)
echo "Waiting for instances to be ready for Ansible..."

# TODO: A more robust check could be implemented using nc and ansible
sleep 15

echo "Starting deployment."

# Make sure your inventory.ini uses the correct ansible_ssh_private_key_file path
# e.g., ansible_ssh_private_key_file=~/.ssh/ansible_key
docker exec instance_a \
  bash -c "ansible-playbook -i '$INVENTORY_NAME' '$PLAYBOOK_NAME'"

echo ""
echo "Ansible playbook execution complete."
echo ""

# --- 5. Verification Information ---
echo "--- Setup and Deployment Complete! ---"
echo "You should now be able to access the Nginx proxy."
echo "Test by opening your browser or using curl:"
echo "  curl http://localhost:80"
echo ""
echo "To bring down the environment (instance_a, instance_b):"
echo "  docker compose down"
echo "Remember to also manually stop/remove 'nginx_ansible_direct_test' if you want a full cleanup:"
echo "  docker stop nginx_ansible_direct_test && docker rm nginx_ansible_direct_test"
echo "And the network if it's no longer needed by other containers:"
echo "  docker network rm provisioning_network_global"
echo ""

exit 0
