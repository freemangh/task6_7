#!/bin/bash
# Mirantis Internship 2018
# Task 6_7
# Eugeniy Khvastunov
# Script for configuration VM2
#
#
# Step 0: Reading variables from config
SCRPATH="$(/bin/readlink -f "$0" | rev | cut -c 7- | rev)"
CONFIGFILE=$SCRPATH'vm2.config'
set -o allexport
source $CONFIGFILE
set +o allexport
#Normalization
INTERNAL_IF=$(echo $INTERNAL_IF | tr -d \'\"\”,)
MANAGEMENT_IF=$(echo $MANAGEMENT_IF | tr -d \'\"\”,)
VLAN=$(echo $VLAN | tr -d \'\"\”,)
GW_IP=$(echo $GW_IP | tr -d \'\"\”,)
INT_IP=$(echo $INT_IP | tr -d \'\"\”,)
APACHE_VLAN_IP=$(echo $APACHE_VLAN_IP | tr -d \'\"\”,)
echo "===CONFIG START===
SCRPATH: $SCRPATH
CONFIGFILE: $CONFIGFILE
INTERNAL_IF: $INTERNAL_IF
MANAGEMENT_IF: $MANAGEMENT_IF
VLAN: $VLAN
GW_IP: $GW_IP
INT_IP: $INT_IP
APACHE_VLAN_IP: $APACHE_VLAN_IP
===CONFIG END==="
#
#
# Step 1: Configuring and bringin up network
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
hostname vm2
echo vm2 > /etc/hostname
echo vm2 >> /etc/hosts
/bin/ip link set dev $INTERNAL_IF up
/bin/ip link set dev $MANAGEMENT_IF up
echo "Creating and bringin up VLAN $VLAN on $INTERNAL_IF"
/bin/ip link add link $INTERNAL_IF name $INTERNAL_IF.$VLAN type vlan id $VLAN
/bin/ip link set dev $INTERNAL_IF.$VLAN up
/bin/ip address add $APACHE_VLAN_IP dev $INTERNAL_IF.$VLAN
/bin/ip route add default via $GW_IP
#
#
# Step 2: Installing and configuring services
/usr/bin/apt-get -y update
/usr/bin/apt-get -y install apache2
