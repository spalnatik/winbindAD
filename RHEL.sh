#!/bin/bash


sudo update-crypto-policies --set DEFAULT:AD-SUPPORT

sudo yum install --disablerepo='*' --enablerepo='*microsoft*' 'rhui-azure-* -y 

sudo yum install realmd oddjob-mkhomedir oddjob samba-winbind-clients samba-winbind samba-common-tools samba-winbind-krb5-locator -y

sudo  yum install samba -y

mv /etc/samba/smb.conf /etc/samba/smb.conf.bak

realm join --membership-software=samba --client-software=winbind intl.contoso.com -U tempadmin
