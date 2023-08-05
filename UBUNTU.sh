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

hostnamectl set-hostname ubuntuAD.intl.contoso.com

cp -p /etc/krb5.conf /etc/krb5.conf_bkp

krb_content="includedir  /etc/krb5.conf.d

[libdefaults]
      dns_lookup_realm = false
      ticket_lifetime = 24h
      renew_lifetime = 7d
      forwardable = true
      rdns = false
      default_realm = INTL.CONTOSO.COM
      default_ccache_name = KEYRING:persistent:%{uid}

[realms]
      INTL.CONTOSO.COM = {
            kdc = intl.contoso.com
            admin_server = intl.contoso.com
            default_domain = intl.contoso.com
            pkinit_anchors = FILE:/etc/pki/nssdb/certificate.pem
            pkinit_cert_match = <KU>digitalSignature
            pkinit_kdc_hostname = intl.contoso.com
      }

[domain_realm]
    .intl.contoso.com = INTL.CONTOSO.COM
    intl.contoso.com = INTL.CONTOSO.COM

sudo echo "$krb_content" > /etc/krb5.conf

