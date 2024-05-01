#!/bin/bash

read -p "Enter website domain: " domain

apt update && apt upgrade -y

hostnamectl set-hostname postal.$domain

sudo apt install ca-certificates curl gnupg lsb-release -y

sudo mkdir -m 0755 -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

apt install git curl jq -y

git clone https://postalserver.io/start/install /opt/postal/install

sudo ln -s /opt/postal/install/bin/postal /usr/bin/postal

docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=postal \
   -e MARIADB_ROOT_PASSWORD=postal \
   mariadb

docker run -d \
   --name postal-rabbitmq \
   -p 127.0.0.1:5672:5672 \
   --restart always \
   -e RABBITMQ_DEFAULT_USER=postal \
   -e RABBITMQ_DEFAULT_PASS=postal \
   -e RABBITMQ_DEFAULT_VHOST=postal \
   rabbitmq:3.8

postal bootstrap postal.$domain

sed -i "s/- mx.postal.example.com/- postal.$domain/" "/opt/postal/config/postal.yml"
sed -i "s/smtp_server_hostname: postal.example.com/smtp_server_hostname: postal.$domain/" "/opt/postal/config/postal.yml"
sed -i "s/spf_include: spf.postal.example.com/spf_include: spf.postal.$domain/" "/opt/postal/config/postal.yml"
sed -i "s/return_path: rp.postal.example.com/return_path: rp.postal.$domain/" "/opt/postal/config/postal.yml"
sed -i "s/route_domain: routes.postal.example.com/route_domain: routes.postal.$domain/" "/opt/postal/config/postal.yml"
sed -i "s/track_domain: track.postal.example.com/track_domain: track.postal.$domain/" "/opt/postal/config/postal.yml"
sed -i "s/from_address: postal.$domain/from_address: postal@$domain/" "/opt/postal/config/postal.yml"

postal initialize

postal make-user

postal start

docker run -d \
   --name postal-caddy \
   --restart always \
   --network host \
   -v /opt/postal/config/Caddyfile:/etc/caddy/Caddyfile \
   -v /opt/postal/caddy-data:/data \
   caddy

postal upgrade

echo "Your Postal SMTP Server link is https://postal.$domain or http://$domain:5000"
echo "Your Postal SMTP Server credential is which you entered"
echo "follow https://inguide.in/simplest-way-to-configure-postal-create-smtp-install-ssl/ for creation of organization and server"
