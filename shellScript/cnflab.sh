#!/usr/bin/bash

# Remove the Default IPv4 Route
sudo route del -net 0.0.0.0 gw 10.1.1.1 netmask 0.0.0.0 dev ens5

# Change DNS Server IPv6's
sudo sed -i 's/DNS=2403:5808:81:20::20/DNS=2403:5808:81:50::20/g' /var/run/systemd/netif/links/3

# Change DNS Server IPv4's
sudo sed -i 's/DNS=10.1.1.2/DNS=/g' /var/run/systemd/netif/links/2

# Restart Service
sudo systemctl restart systemd-resolved