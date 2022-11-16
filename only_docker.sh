#!/bin/bash
mkdir jenkins
wait
sudo apt-get update
wait
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y
wait
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
wait
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
wait
sudo apt-get update
wait
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
wait
sudo groupadd docker
wait
sudo usermod -aG docker "${USER}"
wait