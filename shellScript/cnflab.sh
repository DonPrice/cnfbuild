#!/usr/bin/bash

# Enable Interfaces on Worker Nodes This is to work around UDF, we do not have an IP associated with these interfaces so they are left shut.
USERNAME=ubuntu
HOSTS="10.1.1.6 10.1.1.7 10.1.1.8 10.1.1.12"
SCRIPT="sudo ip link set dev ens6 up; sudo ip link set dev ens7 up"
for HOSTNAME in ${HOSTS} ; do
    ssh -l ${USERNAME} ${HOSTNAME} "${SCRIPT}"
done

# Remove the Default IPv4 Route Client Traffic must route via IPv6 Interface.
sudo route del -net 0.0.0.0 gw 10.1.1.1 netmask 0.0.0.0 dev ens5

# Change NetPlan to disable DHCP and configure static IP.
cat <<EOF > 50-cloud-init.yaml 
network:
  version: 2
  ethernets:
    ens5:
      addresses:
        - 10.1.1.4/24
EOF

sudo cp 50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml

# Change DNS server to IP of DNS APP VIP
sudo sed -i 's/2403:5808:81:20::20/2403:5808:81:50::20/g' /etc/netplan/55-ens6.yaml

sudo netplan apply

# Change DNS Server IPv6's
sudo sed -i 's/DNS=2403:5808:81:20::20/DNS=2403:5808:81:50::20/g' /var/run/systemd/netif/links/3

# Change DNS Server IPv4's
sudo sed -i 's/DNS=10.1.1.2/DNS=/g' /var/run/systemd/netif/links/2

# Restart Service
sudo systemctl restart systemd-resolved