#!/bin/bash
netplan apply

# Create the file and write the content
cat << EOF > /etc/netplan/99-dns.yaml
network:
  ethernets:
    eth0:
      nameservers:
        search: [ contoso.com ]
EOF
netplan apply
systemd-resolve --status

apt update && apt-get install -y samba krb5-config krb5-user winbind libpam-winbind
