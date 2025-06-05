# Dockerfile.b: For Managed Node (Instance B)
FROM ubuntu:latest

# Install necessary packages: openssh-server, python3, and sudo
# Docker and Docker Compose will be installed by Ansible later
RUN apt-get update && \
    apt-get install -y openssh-server python3 sudo net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a dedicated user for Ansible operations
RUN useradd -m -s /bin/bash ansible
# Set a simple password for initial access/debugging from host (e.g., ssh -p 2223 ansible@localhost)
RUN echo "ansible:ansible" | chpasswd
# Grant sudo privileges to the 'ansible' user
RUN usermod -aG sudo ansible

# Allow user 'ansible' to run sudo without a password
RUN echo "ansible ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansible
# Ensure the permissions are correct for sudoers files
RUN chmod 0440 /etc/sudoers.d/ansible

# Configure SSH for passwordless login for the ansible user
RUN mkdir -p /home/ansible/.ssh && \
    chmod 700 /home/ansible/.ssh && \
    chown ansible:ansible /home/ansible/.ssh

# Allow password authentication for SSH (for initial setup/debugging from host)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Create privilege separation directory for sshd
RUN mkdir -p /run/sshd

# Expose the SSH port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]