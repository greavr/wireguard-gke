#! /bin/bash
sudo apt update
sudo apt install -y wireguard nfs-kernel-server nfs-common curl tcpdump 

## Install CloudOps
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

## Setup NFS
sudo mkdir -p /export/kubernetes
sudo chown nobody:nogroup /export/kubernetes
echo "/export/kubernetes               10.0.0.0/8(rw,sync,no_root_squash,no_subtree_check)" >> /etc/exports
sudo systemctl restart nfs-kernel-server

## Install Docker
curl -fsSL https://test.docker.com -o test-docker.sh
sudo sh test-docker.sh

sudo usermod -aG docker $(logname)