#!/bin/bash

# This script is used to fix all permission errors encountered when mounting host files to a
# container which might or not have the files defined. Because of the way Docker may be
# installed in the local host, this could cause permission errors and alike (e.g. files are created by root)

# Ensure the mounted ansible_project directory and its contents are owned by the 'ansible' user
# This is crucial because host-mounted volumes often default to root ownership inside the container.
echo "Setting ownership for /home/ansible/ansible_project..."
chown -R ansible:ansible /home/ansible/ansible_project
# Make sure only the owner has write permissions for the project directory
chmod -R u+rwX,go-w /home/ansible/ansible_project
echo "Permissions for /home/ansible/ansible_project set."

# Ensure .ssh directory and id_rsa file are owned by ansible user at runtime
# The .ssh directory itself needs to be owned by the user and have strict permissions (0700)
echo "Setting ownership and strict permissions for /home/ansible/.ssh/..."
chown ansible:ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh

# Set strict permissions for the private SSH key.
# This is critical for SSH security: private keys must only be readable by the owner (0600).
echo "Setting strict permissions for /home/ansible/.ssh/id_rsa..."
chown ansible:ansible /home/ansible/.ssh/id_rsa # Ensure ownership before chmod
chmod 600 /home/ansible/.ssh/id_rsa
echo "Permissions for id_rsa set."

# Execute the main command passed to the container (which is typically /usr/sbin/sshd -D)
# 'exec "$@"' replaces the shell process with the command, ensuring signals are handled correctly
exec "$@"