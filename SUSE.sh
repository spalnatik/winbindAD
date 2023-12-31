#!/bin/bash


#domain_name=$1
#domain_admin_username=$1
#domain_admin_password=$2

#krb5 configuration
cp -p /etc/krb5.conf /etc/krb5.conf_bkp

krb_content="includedir  /etc/krb5.conf.d

[libdefaults]
    default_realm = INTL.CONTOSO.COM
    #dns_lookup_kdc = true
    forwardable = true
    default_ccache_name = FILE:/tmp/krb5cc_%{uid}
[realms]
    INTL.CONTOSO.COM = {
        admin_server = intl.contoso.com
        #kdc = dc1.example.com
        #kdc = dc2.example.com
    }
[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON
[domain_realm]
    .intl.contoso.com = INTL.CONTOSO.COM
    intl.contoso.com = INTL.CONTOSO.COM"

sudo echo "$krb_content" > /etc/krb5.conf

sudo zypper  -n install samba-client samba-libs samba-winbind

sudo cp /etc/samba/smb.conf /etc/samba/smb.conf_bkp

# samba configuration 
new_content="[global]
    workgroup = CONTOSO
    kerberos method = secrets and keytab
    realm = INTL.CONTOSO.COM
    security = ADS

    winbind refresh tickets = yes
    winbind use default domain = yes
    template shell = /bin/bash
    template homedir = /home/%D/%U

    idmap config * : backend = tdb
    idmap config * : range = 10000-19999
    idmap config CONTOSO : backend = rid
    idmap config CONTOSO : range = 20000-29999
[homes]
        comment = Home Directories
        valid users = %S, %D%w%S
        browseable = No
        read only = No
        inherit acls = Yes
[profiles]
        comment = Network Profiles Service
        path = %H
        read only = No
        store dos attributes = Yes
        create mask = 0600
        directory mask = 0700
[users]
        comment = All users
        path = /home
        read only = No
        inherit acls = Yes
        veto files = /aquota.user/groups/shares/
[groups]
        comment = All groups
        path = /home/groups
        read only = No
        inherit acls = Yes
[printers]
        comment = All Printers
        path = /var/tmp
        printable = Yes
        create mask = 0600
        browseable = No
[print$]
        comment = Printer Drivers
        path = /var/lib/samba/drivers
        write list = @ntadmin root
        force group = ntadmin
        create mask = 0664
        directory mask = 0775"

echo "$new_content" >  /etc/samba/smb.conf

sed -i 's/^group:[[:space:]]*compat[[:space:]]*$/group:          compat winbind/' /etc/nsswitch.conf
sed -i 's/^passwd:[[:space:]]*compat[[:space:]]*$/passwd:         compat winbind/' /etc/nsswitch.conf



hostname=`hostname`

hostnamectl set-hostname $hostname.intl.contoso.com

ip=$(hostname -I | awk '{print $1}')

echo "$ip        $hostname.intl.contoso.com $hostname" >> /etc/hosts

#echo "$domain_admin_password" | kinit $domain_admin_username
echo "$2" | kinit $1

net ads join -k

systemctl enable winbind

systemctl start winbind

new_lines="[global]
krb5_auth = yes
krb5_ccache_type = FILE"

sudo sed -i '/^\[global\]/a\'$'\n''krb5_auth = yes\'$'\n''krb5_ccache_type = FILE' "/etc/security/pam_winbind.conf"

pam-config -a --winbind
pam-config -a --mkhomedir

reboot
