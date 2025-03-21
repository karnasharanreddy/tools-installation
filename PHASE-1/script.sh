#!/bin/bash
set -e

# Step 1: Disable Swap & Update System
echo "Disabling swap and updating system..."
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo apt update && sudo apt upgrade -y

# Step 2: Install Required Packages
echo "Installing required packages..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Step 3: Install containerd
echo "Installing containerd..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Step 4: Install Kubernetes Components
echo "Installing Kubernetes components..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.asc] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet

# Step 5: Initialize Kubernetes (Control Plane Only)
if [ "$1" == "master" ]; then
    echo "Initializing Kubernetes cluster..."
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket /run/containerd/containerd.sock

    echo "Setting up kubectl for current user..."
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo "Installing Calico CNI..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

    echo "Verifying installation..."
    kubectl get pods -n kube-system

    echo "Kubernetes master node setup completed."
else
    echo "Skipping master setup, expecting worker node setup."
    echo "To join a worker node, retrieve the join command from the master node using:"
    echo "  kubeadm token create --print-join-command"
    echo "Then run the output command on this worker node."
fi

echo "Installation complete. Verify using: kubectl get nodes"
