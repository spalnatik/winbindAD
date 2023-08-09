#!/bin/bash

timestamp=$(date +"%Y-%m-%d %H:%M:%S")

echo "Script execution started at: $timestamp"

#set -x

vmname1="win2019adserver"
#vmname2="rhelad"
rgname="Lab_Azure_ADINTG"
offer="MicrosoftWindowsServer:WindowsServer:2019-datacenter-smalldisk:latest"
offer1="OpenLogic:CentOS:7_9:latest"
loc="eastus"
sku_size="Standard_D2s_v3"
vnetname="AD-vnet"
subnetname="ADsubnet"
logfile="win.log"


if [ -f "./vmname2.txt" ]; then
    vmname2=$(cat vmname2.txt)
else
    read  -p "Please enter the linux vmname: " vmname2
fi

function check_resource_group_exists {
    az group show --name "$1" &> /dev/null
}


# Parse command line arguments
while getopts "i:" opt; do
  case $opt in
    i) offer1=$OPTARG ;;
    *) ;;
  esac
done

echo "Offer1: $offer1"



if [ -f "./username.txt" ]; then
    username=$(cat username.txt)
else
    read -p "Please enter the username: " username
fi

if [ -f "./password.txt" ]; then
    password=$(cat password.txt)
else
    read -s -p "Please enter the password: " password
fi

domain_admin_username=$username
domain_admin_password=$password


#
echo ""
date >> "$logfile"

function winbind {

if check_resource_group_exists "$rgname"; then
    echo "Resource group '$rgname' already exists. Skipping AD integration..."
else
    echo "Creating RG $rgname.."
    az group create --name "$rgname" --location "$loc" >> "$logfile"

    echo "Creating VNET .."
    az network vnet create --name "$vnetname" -g "$rgname" --address-prefixes 10.0.0.0/24 --subnet-name "$subnetname" --subnet-prefixes 10.0.0.0/24 >> "$logfile"

    echo "Creating windows AD Domain server"
    az vm create -g "$rgname" -n "$vmname1" --admin-username "$username" --admin-password "$password" --image "$offer" --vnet-name "$vnetname" --subnet "$subnetname" --public-ip-sku Standard >> "$logfile"

    if [ -f domain_install.ps1 ]
    then
        rm ./domain_install.ps1
        echo "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" >> domain_install.ps1
        echo "\$pass = ConvertTo-SecureString -String $password -AsPlainText -Force " >> domain_install.ps1
        echo "Install-ADDSForest -DomainName \"intl.contoso.com\" -DomainNetBiosName \"CONTOSO\" -InstallDns:\$true -NoRebootOnCompletion:\$true -SafeModeAdministratorPassword \$pass -Force " >> domain_install.ps1
        echo 'shutdown -r' >> domain_install.ps1
    else
        echo "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" >> domain_install.ps1
        echo "\$pass = ConvertTo-SecureString -String $password -AsPlainText -Force " >> domain_install.ps1
        echo "Install-ADDSForest -DomainName \"ntl.contoso.com\" -DomainNetBiosName \"CONTOSO\" -InstallDns:\$true -NoRebootOnCompletion:\$true -SafeModeAdministratorPassword \$pass -Force " >> domain_install.ps1
        echo 'shutdown -r' >> domain_install.ps1
    fi

    echo 'Promoting the domain server, this operation might take some time ..'
    az vm run-command invoke  --command-id RunPowerShellScript --name $vmname1 -g $rgname --scripts @domain_install.ps1 >> /dev/null

    echo 'Updating the VNET to have the domain server IP as its DNS server'
    win_private_ip=`az vm list-ip-addresses -g $rgname -n $vmname1 --query [].virtualMachine.network.privateIpAddresses -o tsv`
    vnet_name=`az network vnet list -g $rgname --query [].name -o tsv`
    az network vnet update -g $rgname -n $vnet_name --dns-servers $win_private_ip 168.63.129.16 >> /dev/null

    echo 'Waiting for the windows machine for 3 min'
    sleep 180
    
fi

echo "Creating Linux AD integrating server"
az vm create -g "$rgname" -n "$vmname2" --admin-username "$username" --admin-password "$password" --image $offer1 --vnet-name "$vnetname" --subnet "$subnetname" --public-ip-sku Standard  >> "$logfile"

shopt -s nocasematch

if [[ $offer1 == *"Canonical"* ]]; then
    echo 'installing winbind and other packages'
az vm extension set \
    --resource-group $rgname \
    --vm-name $vmname2 \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/spalnatik/winbindAD/main/UBUNTU.sh\"], \"commandToExecute\": \"./UBUNTU.sh $domain_admin_username $domain_admin_password\"}" >> $logfile

elif [[ $offer1 == *"suse"* ]]; then
    echo 'installing winbind and other packages'

az vm extension set \
    --resource-group $rgname \
    --vm-name $vmname2 \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/spalnatik/winbindAD/main/SUSE.sh\"], \"commandToExecute\": \"./SUSE.sh $domain_admin_username $domain_admin_password\"}" >> $logfile

elif [[ $offer1 == *"OpenLogic"* || $offer1 == *"redhat"* ]]; then
     echo 'installing winbind and other packages'

az vm extension set \
    --resource-group $rgname \
    --vm-name $vmname2 \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/spalnatik/winbindAD/main/ad.sh\"], \"commandToExecute\": \"./ad.sh $domain_admin_username $domain_admin_password\"}" >> $logfile


else
    # Invalid offer1 value
    echo "Invalid offer1 value. No script to execute."

fi

shopt -u nocasematch



my_pip=`curl ifconfig.io`
nsg_list=`az network nsg list -g $rgname  --query [].name -o tsv`
for i in $nsg_list
    do
        az network nsg rule create -g $rgname --nsg-name $i -n buildInfraRule --priority 100 --source-address-prefixes $my_pip  --destination-port-ranges 3389 --access Allow --protocol Tcp >> $logfile

        az network nsg rule create -g $rgname --nsg-name $i -n buildInfraRule --priority 101 --source-address-prefixes $my_pip  --destination-port-ranges 22 --access Allow --protocol Tcp >> $logfile
done

end_time=$(date +"%Y-%m-%d %H:%M:%S")

echo "Script execution completed at: $end_time"

}

function sssd {

if check_resource_group_exists "$rgname"; then
    echo "Resource group '$rgname' already exists. Skipping AD integration..."
else
    echo "Creating RG $rgname.."
    az group create --name "$rgname" --location "$loc" >> "$logfile"

    echo "Creating VNET .."
    az network vnet create --name "$vnetname" -g "$rgname" --address-prefixes 10.0.0.0/24 --subnet-name "$subnetname" --subnet-prefixes 10.0.0.0/24 >> "$logfile"

    echo "Creating windows AD Domain server"
    az vm create -g "$rgname" -n "$vmname1" --admin-username "$username" --admin-password "$password" --image "$offer" --vnet-name "$vnetname" --subnet "$subnetname" --public-ip-sku Standard >> "$logfile"

    if [ -f domain_install.ps1 ]
    then
        rm ./domain_install.ps1
        echo "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" >> domain_install.ps1
        echo "\$pass = ConvertTo-SecureString -String $password -AsPlainText -Force " >> domain_install.ps1
        echo "Install-ADDSForest -DomainName \"intl.contoso.com\" -DomainNetBiosName \"CONTOSO\" -InstallDns:\$true -NoRebootOnCompletion:\$true -SafeModeAdministratorPassword \$pass -Force " >> domain_install.ps1
        echo 'shutdown -r' >> domain_install.ps1
    else
        echo "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" >> domain_install.ps1
        echo "\$pass = ConvertTo-SecureString -String $password -AsPlainText -Force " >> domain_install.ps1
        echo "Install-ADDSForest -DomainName \"ntl.contoso.com\" -DomainNetBiosName \"CONTOSO\" -InstallDns:\$true -NoRebootOnCompletion:\$true -SafeModeAdministratorPassword \$pass -Force " >> domain_install.ps1
        echo 'shutdown -r' >> domain_install.ps1
    fi

    echo 'Promoting the domain server, this operation might take some time ..'
    az vm run-command invoke  --command-id RunPowerShellScript --name $vmname1 -g $rgname --scripts @domain_install.ps1 >> /dev/null

    echo 'Updating the VNET to have the domain server IP as its DNS server'
    win_private_ip=`az vm list-ip-addresses -g $rgname -n $vmname1 --query [].virtualMachine.network.privateIpAddresses -o tsv`
    vnet_name=`az network vnet list -g $rgname --query [].name -o tsv`
    az network vnet update -g $rgname -n $vnetname --dns-servers $win_private_ip 168.63.129.16 >> /dev/null

    echo 'Waiting for the windows machine for 3 min'
    sleep 180

    
fi

echo "Creating Linux AD integrating server"
az vm create -g "$rgname" -n "$vmname2" --admin-username "$username" --admin-password "$password" --image $offer1 --vnet-name "$vnetname" --subnet "$subnetname" --public-ip-sku Standard  >> "$logfile"



shopt -s nocasematch

if [[ $offer1 == *"Canonical"* ]]; then
    echo 'installing sssd and other packages'

az vm extension set \
    --resource-group "$rgname" \
    --vm-name "$vmname2" \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings '{
        "fileUris": ["https://raw.githubusercontent.com/spalnatik/spalnati/main/ubuntu.sh"],
        "commandToExecute": "apt update && apt install realmd oddjob oddjob-mkhomedir sssd sssd-tools sssd-ad adcli packagekit samba-common -y  && chmod +x ubuntu.sh && ./ubuntu.sh"    }' >> "$logfile"

win_private_ip=`az vm list-ip-addresses -g $rgname -n $vmname1 --query [].virtualMachine.network.privateIpAddresses -o tsv`

az vm run-command invoke   --resource-group $rgname   --name $vmname2   --command-id RunShellScript   --scripts "echo $win_private_ip $vmname1.intl.contoso.com $vmname1 >> /etc/hosts"

elif [[ $offer1 == *"suse"* ]]; then
    echo 'installing sssd and other packages'

az vm extension set \
    --resource-group "$rgname" \
    --vm-name "$vmname2" \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings '{
        "fileUris": ["https://raw.githubusercontent.com/spalnatik/spalnati/main/suse.sh"],
        "commandToExecute": "zypper -n install realmd sssd sssd-tools adcli krb5-client samba-client openldap2-client sssd-ad && chmod +x suse.sh && ./suse.sh"    }' >> "$logfile"

#elif [[ "$offer1" == *"rhel"* || "$offer1" == *"CentOS"* ]]; then
elif [[ $offer1 == *"OpenLogic"* || $offer1 == *"redhat"* ]]; then
     echo 'installing sssd and other packages'

az vm extension set \
    --resource-group "$rgname" \
    --vm-name "$vmname2" \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings '{
        "fileUris": ["https://raw.githubusercontent.com/spalnatik/spalnati/main/ad.sh"],
        "commandToExecute": "yum install -y adcli krb5-workstation nmap oddjob oddjob-mkhomedir realmd samba-common-tools sssd && chmod +x ad.sh && ./ad.sh"    }' >> "$logfile"

else
    # Invalid offer1 value
    echo "Invalid offer1 value. No script to execute."

fi

shopt -u nocasematch

echo 'Updating NSGs with public IP and allowing ssh access(linux vm) and rdp (windows VM) from that IP'

my_pip=`curl ifconfig.io`
nsg_list=`az network nsg list -g $rgname  --query [].name -o tsv`
for i in $nsg_list
    do
        az network nsg rule create -g $rgname --nsg-name $i -n buildInfraRule --priority 100 --source-address-prefixes $my_pip  --destination-port-ranges 3389 --access Allow --protocol Tcp >> $logfile

        az network nsg rule create -g $rgname --nsg-name $i -n buildInfraRule --priority 101 --source-address-prefixes $my_pip  --destination-port-ranges 22 --access Allow --protocol Tcp >> $logfile
done

#echo 'sleep for 2 mins until windows server is up'

#sleep 120


echo 'adding server to the domain'
az vm run-command invoke   --resource-group $rgname   --name $vmname2   --command-id RunShellScript   --scripts "echo $password | realm join intl.contoso.com -U $username" >> $logfile


end_time=$(date +"%Y-%m-%d %H:%M:%S")

echo "Script execution completed at: $end_time"

}

# Read the user's choice for AD integration method
echo "Choose the AD integration method:"
echo "1. SSSD"
echo "2. Winbind"
read -p "Enter the number of your choice: " choice

# Execute the corresponding function based on the user's choice
case $choice in
    1) sssd ;;
    2) winbind ;;
    *) echo "Invalid choice. Please choose a valid option (1-2)." ;;
esac

