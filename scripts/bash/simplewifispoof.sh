#!/bin/bash

INTERFACE=en0
MACADDRESS=$(ifconfig en0 | grep ether| cut -d ' ' -f 2)
NEWMACADDRESS=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')

echo -n "Enter root password: "
read PW

echo "Current MAC address: $CURMACADDRESS"

echo "Dissociating from the network"
echo $PW | sudo /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -z

echo "Setting MAC address for ifconfig $INTERFACE (ether, $MACADDRESS)"
sudo ifconfig $INTERFACE ether $NEWMACADDRESS

echo "Detecting hardware changes."
sudo networksetup -detectnewhardware
echo "New MAC address for interface $INTERFACE set to $NEWMACADDRESS"

echo "Turning WIFI off"
sudo networksetup -setairportpower $INTERFACE off

echo "Turning WIFI on"
sudo networksetup -setairportpower $INTERFACE on

