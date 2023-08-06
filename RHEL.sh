#!/bin/bash


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

sudo update-crypto-policies --set DEFAULT:AD-SUPPORT

sudo yum install realmd oddjob-mkhomedir oddjob samba-winbind-clients samba-winbind samba-common-tools samba-winbind-krb5-locator -y

sudo  yum install samba -y

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

# Define the lines to be added to the krb5.conf file
lines_to_add="[plugins]
    localauth = {
        module = winbind:/usr/lib64/samba/krb5/winbind_krb5_localauth.so
        enable_only = winbind
    }"

# File path to the krb5.conf file
krb5_conf="/etc/krb5.conf"

echo "$lines_to_add" | sudo tee -a "$krb5_conf"

systemctl enable --now smb

yum install krb5-workstation -y 

hostname=`hostname`

hostnamectl set-hostname $hostname.intl.contoso.com

echo "10.0.0.15        $hostname.intl.contoso.com $hostname" >> /etc/hosts


sudo sed -i 's/^passwd:.*$/passwd:    files winbind systemd/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*$/group:    files winbind systemd/' /etc/nsswitch.conf

sudo echo "$2" | kinit $1

net ads join -k

systemctl enable winbind

systemctl start winbind

new_lines="[global]
krb5_auth = yes
krb5_ccache_type = FILE"
sudo sed -i '/^\[global\]/a\'$'\n''krb5_auth = yes\'$'\n''krb5_ccache_type = FILE' "/etc/security/pam_winbind.conf"


