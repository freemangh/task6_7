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
/usr/bin/apt-get -y update
/usr/bin/apt-get -y install openssl nginx
