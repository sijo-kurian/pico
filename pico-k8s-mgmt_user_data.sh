#!/bin/bash

# Install Ansible
apt-get update && apt-get upgrade -y && apt-get install -y ansible
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubectl

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
rm -rf /tmp/aws
rm /tmp/awscliv2.zip

# Mkdir /opt/ansible
mkdir /opt/ansible

echo "${nlb_dns_name}" > /opt/ansible/nlb_dns_name

# Generate ansible_inventory file

echo "[primary]" >> /opt/ansible/inventory
echo "master1 ansible_host=${master1_ip} ansible_user=ubuntu" >> /opt/ansible/inventory
echo "[backup]" >> /opt/ansible/inventory
echo "master2 ansible_host=${master2_ip} ansible_user=ubuntu" >> /opt/ansible/inventory
echo "[workers]" >> /opt/ansible/inventory
echo "worker1 ansible_host=${worker1_ip} ansible_user=ubuntu" >> /opt/ansible/inventory
echo "worker2 ansible_host=${worker2_ip} ansible_user=ubuntu" >> /opt/ansible/inventory













