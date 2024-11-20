#!/bin/bash

# Update and Upgrade Ubuntu Packages
echo "Updating and Upgrading Ubuntu Packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Load necessary kernel modules
echo "Loading required kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl params required by Kubernetes
echo "Setting sysctl params for Kubernetes networking..."
sudo sysctl net.bridge.bridge-nf-call-iptables=1
sudo sysctl net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl -w net.ipv4.ip_forward=1

# Make sysctl changes permanent
echo "Making sysctl changes permanent..."
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Install Containerd
echo "Installing Containerd..."
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Disable Swap (required for Kubernetes)
echo "Disabling Swap..."
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

# Add Kubernetes Repository
echo "Adding Kubernetes Repository..."
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# Install Kubeadm, Kubelet, and Kubectl
echo "Installing Kubeadm, Kubelet, and Kubectl..."
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl