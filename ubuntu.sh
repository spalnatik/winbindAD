#!/bin/bash

domain_name=$1
domain_admin_username=$2
domain_admin_password=$3

netplan apply

# Create the file and write the content
cat << EOF > /etc/netplan/99-dns.yaml
network:
  ethernets:
    eth0:
      nameservers:
        search: [ lab.local ]
EOF
netplan apply
systemd-resolve --status

echo "krb5-config krb5-config/default_realm string lab.local" > krb5-config.seed
sudo debconf-set-selections < krb5-config.seed
apt update && apt-get install -y samba krb5-config krb5-user winbind libpam-winbind

cp -p /etc/krb5.conf /etc/krb5.conf_bkp

krb_content="[libdefaults]
      dns_lookup_realm = false
      ticket_lifetime = 24h
      renew_lifetime = 7d
      forwardable = true
      rdns = false
      default_realm = LAB.LOCAL
      default_ccache_name = KEYRING:persistent:%{uid}

[realms]
      LAB.LOCAL = {
            kdc = lab.local
            admin_server = lab.local
            default_domain = lab.local
            pkinit_anchors = FILE:/etc/pki/nssdb/certificate.pem
            pkinit_cert_match = <KU>digitalSignature
            pkinit_kdc_hostname = lab.local
      }

[domain_realm]
    .lab.local = LAB.LOCAL
    lab.local = LAB.LOCAL"

sudo echo "$krb_content" > /etc/krb5.conf

sudo cp /etc/samba/smb.conf /etc/samba/smb.conf_bkp

# samba configuration 
new_content="[global]
        security = ads
        realm = LAB.LOCAL
        workgroup = LAB
        idmap uid = 10000-20000
        idmap gid = 10000-20000
        winbind enum users = yes
        winbind enum groups = yes
        template homedir = /home/%D/%U
        template shell = /bin/bash
        client use spnego = yes
        client ntlmv2 auth = yes
        encrypt passwords = yes
        winbind use default domain = yes
        restrict anonymous = 2"

echo "$new_content" >  /etc/samba/smb.conf

sudo sed -i 's/^passwd:.*$/passwd:    compat systemd winbind/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*$/group:     compat systemd winbind/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*$/shadow:     compat/' /etc/nsswitch.conf


hostname=`hostname`

hostnamectl set-hostname $hostname.lab.local

ip=$(hostname -I | awk '{print $1}')

echo "$ip        $hostname.lab.local $hostname" >> /etc/hosts

echo "$domain_admin_password" | kinit $domain_admin_username
#echo "$2" | kinit $1

echo "$domain_admin_password" | net ads join -U  $domain_admin_username

systemctl enable smbd nmbd winbind
systemctl restart smbd nmbd winbind

sudo pam-auth-update --enable mkhomedir
