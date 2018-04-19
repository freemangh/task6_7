#!/bin/bash
# Mirantis Internship 2018
# Task 6_7
# Eugeniy Khvastunov
# Script for configuration VM1
# Step 0: Reading variables from config
SCRPATH="$(/bin/readlink -f "$0" | rev | cut -c 7- | rev)"
CONFIGFILE=$SCRPATH'vm1.config'
set -o allexport
source $CONFIGFILE
set +o allexport
#Normalization
EXTERNAL_IF=$(echo $EXTERNAL_IF | tr -d \'\"\”,)
INTERNAL_IF=$(echo $INTERNAL_IF | tr -d \'\"\”,)
MANAGEMENT_IF=$(echo $MANAGEMENT_IF | tr -d \'\"\”,)
VLAN=$(echo $VLAN | tr -d \'\"\”,)
EXT_IP=$(echo $EXT_IP | tr -d \'\"\”,)
EXT_GW=$(echo $EXT_GW | tr -d \'\"\”,)
INT_IP=$(echo $INT_IP | tr -d \'\"\”,)
VLAN_IP=$(echo $VLAN_IP | tr -d \'\"\”,)
NGINX_PORT=$(echo $NGINX_PORT | tr -d \'\"\”,)
APACHE_VLAN_IP=$(echo $APACHE_VLAN_IP | tr -d \'\"\”,)
echo "===CONFIG START===
SCRPATH: $SCRPATH
CONFIGFILE: $CONFIGFILE
EXTERNAL_IF: $EXTERNAL_IF
INTERNAL_IF: $INTERNAL_IF
MANAGEMENT_IF: $MANAGEMENT_IF
VLAN: $VLAN
EXT_IP: $EXT_IP
EXT_GW: $EXT_GW
INT_IP: $INT_IP
VLAN_IP: $VLAN_IP
NGINX_PORT: $NGINX_PORT
APACHE_VLAN_IP: $APACHE_VLAN_IP
===CONFIG END==="
#
#
# Step 1: Configuring and bringin up network
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
hostname vm1
echo vm1 > /etc/hostname
echo vm1 >> /etc/hosts
/bin/ip link set dev $EXTERNAL_IF up
/bin/ip link set dev $INTERNAL_IF up
/bin/ip link set dev $MANAGEMENT_IF up
if [ -z $EXT_GW ]
then
	echo "Configuring $EXTERNAL_IF with DHCP"
	/sbin/dhclient $EXTERNAL_IF
else
        echo "Configuring $EXTERNAL_IF with static IP"
	/sbin/ifconfig $EXTERNAL_IF $EXT_IP up
	/bin/ip route add default via $EXT_GW
fi
echo "Enabling packet forwarding"
/sbin/sysctl -w net.ipv4.ip_forward=1
echo "Enabling NAT on $EXTERNAL_IF"
/sbin/iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -j MASQUERADE
echo "Configuring $INTERNAL_IF"
/sbin/ifconfig $INTERNAL_IF $INT_IP up
echo "Creating and bringin up VLAN $VLAN on $INTERNAL_IF"
/bin/ip link add link $INTERNAL_IF name $INTERNAL_IF.$VLAN type vlan id $VLAN
/bin/ip link set dev $INTERNAL_IF.$VLAN up
/sbin/ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP/24 up
#
#
# Step 2: Installing and configuring services
/usr/bin/apt-get -y -q update
/usr/bin/apt-get -y -q install openssl nginx

echo "Determinating IP for NGINX..."
NGINX_IP=$(/sbin/ifconfig $EXTERNAL_IF | sed -n '2 p' | awk '{print $2}' | awk -F: '{print $2}')
echo "NGINX IP: $NGINX_IP"

mkdir -p /etc/ssl/certs

openssl genrsa -out /etc/ssl/certs/root-ca.key 4096
openssl req -x509 -new -nodes -key /etc/ssl/certs/root-ca.key -sha256 -days 365 -out /etc/ssl/certs/root-ca.crt -subj "/C=UA/ST=Kharkov/L=Kharkov/O=Mirantis/OU=Internship/CN=vm1/subjectAltName=DNS:vm1,IP:$NGINX_IP/"
openssl genrsa -out /etc/ssl/certs/web.key 2048
openssl req -new -out /etc/ssl/certs/web.csr -key /etc/ssl/certs/web.key -subj "/C=UA/ST=Kharkov/L=Kharkov/O=Mirantis/OU=Internship/CN=vm1/subjectAltName=DNS:vm1,IP:$NGINX_IP/"
openssl x509 -req -in /etc/ssl/certs/web.csr -CA /etc/ssl/certs/root-ca.crt -CAkey /etc/ssl/certs/root-ca.key -CAcreateserial -out /etc/ssl/certs/web.crt

cat /etc/ssl/certs/root-ca.crt /etc/ssl/certs/web.crt > /etc/ssl/certs/chain.pem

echo "server {
	listen $NGINX_IP:$NGINX_PORT ssl default_server;
	# listen [::]:443 ssl default_server;

	#root /var/www/html;

	# Add index.php to the list if you are using PHP
	#index index.html index.htm index.nginx-debian.html;

	server_name _;
	ssl_certificate /etc/ssl/certs/chain.pem;
	ssl_certificate_key /etc/ssl/certs/root-ca.key;

	location / {
		proxy_set_header HOST $host;
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_pass http://$APACHE_VLAN_IP:80$request_uri;
	}

}" > /etc/nginx/sites-enabled/default
/usr/sbin/service nginx restart
