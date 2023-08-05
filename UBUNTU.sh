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
    intl.contoso.com = INTL.CONTOSO.COM"

sudo echo "$krb_content" > /etc/krb5.conf

sudo cp /etc/samba/smb.conf /etc/samba/smb.conf_bkp

# samba configuration 
new_content="[global]
        security = ads
        realm = INTL.CONTOSO.COM
        workgroup = CONTOSO
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

sed -i 's/^group:[[:space:]]*compat[[:space:]]*$/group:          compat winbind/' /etc/nsswitch.conf
sed -i 's/^passwd:[[:space:]]*compat[[:space:]]*$/passwd:         compat winbind/' /etc/nsswitch.conf



hostname=`hostname`

hostnamectl set-hostname $hostname.intl.contoso.com

echo "10.0.0.8        $hostname.intl.contoso.com $hostname" >> /etc/hosts

#echo "$domain_admin_password" | kinit $domain_admin_username
echo "$2" | kinit $1

net ads join -k

systemctl enable smbd nmbd winbind
systemctl restart smbd nmbd winbind

pam-auth-update
