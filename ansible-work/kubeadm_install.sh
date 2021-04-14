#!/bin/bash

# Wrapper script to install the ansible-playbooks required to create the cluster
# Add the ssh-key
if [ -z "$SSH_AUTH_SOCK" ]; then
        exec ssh-agent bash -c "ssh-add $ANSIBLE_KEY_FILE; $0"
        exit
fi

# Prepare the initial ssh key capturing
ansible-playbook initial_connection.yml -i /opt/ansible/inventory
# Playbooks to create the Kubeadm would be run now

ansible-playbook master_config.yml -i /opt/ansible/inventory
#sleep 100
echo Waiting for the Kuberenetes cluster to be ready
# proceeding to configure the backup cluster
ansible-playbook backup_config.yml -i /opt/ansible/inventory
echo Waiting for the backup up server to be ready
#sleep 60
# playbook to join the worker nodes
ansible-playbook worker_config.yml -i /opt/ansible/inventory

