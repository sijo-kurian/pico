#!/bin/bash

# Install kubeadm and Docker
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y python
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Disable swap
swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

# Network changes
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Fix host names
hostnamectl set-hostname $(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
echo "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)  $(curl -s http://169.254.169.254/latest/meta-data/hostname)" >> /etc/hosts


# Install docker
apt-get update && sudo apt-get upgrade -y && sudo apt-get install -y apt-transport-https curl jq
apt-get install docker.io -y
systemctl enable docker.service
systemctl start docker.service

#distribute ssh-key

echo "${ansible_ssh_key}" >> /home/ubuntu/.ssh/authorized_keys




