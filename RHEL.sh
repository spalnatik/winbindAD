#!/bin/bash


sudo update-crypto-policies --set DEFAULT:AD-SUPPORT

#sudo yum install --disablerepo='*' --enablerepo='*microsoft*' 'rhui-azure-* -y 

sudo yum install realmd oddjob-mkhomedir oddjob samba-winbind-clients samba-winbind samba-common-tools samba-winbind-krb5-locator -y

sudo  yum install samba -y

sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak

sudo echo "$2" |realm join --membership-software=samba --client-software=winbind intl.contoso.com -U $1


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

sudo echo "$2" | kinit $1

hostname=`hostname`

hostnamectl set-hostname $hostname.intl.contoso.com

echo "10.0.0.9        $hostname.intl.contoso.com $hostname" >> /etc/hosts

net ads join -k
