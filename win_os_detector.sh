#!/bin/bash
# this script is used to detect what is the OS version , download and execute the script for that version

logdir='/var/log/azure/domain-join'
mkdir -p $logdir
logfile='/var/log/azure/domain-join/os-detector.log'
touch $logfile
domain_name=$1
domain_admin_username=$2
domain_admin_password=$3

echo "#######################" >> $logfile
date >> $logfile
echo "Trying to determine the distro version the machine using" >> $logfile
echo "Checking if the os-release file is available, else check on distro release file" >> $logfile
if [ -f /etc/os-release ]
then
    source /etc/os-release
    case $NAME in
        'SLES')
            echo "This is a suse machine " >> $logfile
            echo "Downloading the script for suse from github and execute it " >> $logfile
            wget -O sles.sh https://raw.githubusercontent.com/spalnatik/winbindAD/main/sles.sh
            chmod +x sles.sh
            echo "executing the script .." >> $logfile
            ./sles.sh $domain_name $domain_admin_username $domain_admin_password
            ;;
        'Ubuntu')
            echo "This is a Ubuntu machine " >> $logfile
            echo "Downloading the script for Ubuntu from github and execute it " >> $logfile
            wget -O ubuntu.sh https://raw.githubusercontent.com/spalnatik/winbindAD/main/ubuntu.sh
            chmod +x ubuntu.sh
            echo "executing the script .." >> $logfile
            ./ubuntu.sh $domain_name $domain_admin_username $domain_admin_password
            ;;
        'CentOS Linux')
            echo "This is a Centos machine " >> $logfile
            echo "Downloading the script for Centos from github and execute it " >> $logfile
            wget -O centos.sh https://raw.githubusercontent.com/spalnatik/winbindAD/main/centos.sh
            chmod +x centos.sh
            echo "executing the script .." >> $logfile
            ./centos.sh $domain_name $domain_admin_username $domain_admin_password
            ;;
        'Red Hat Enterprise Linux')
            echo "This is a Redhat  machine " >> $logfile
            echo "Downloading the script for Redhat  from github and execute it " >> $logfile
            wget -O redhat.sh https://raw.githubusercontent.com/spalnatik/winbindAD/main/redhat.sh
            chmod +x redhat.sh
            echo "executing the script .." >> $logfile
            ./redhat.sh $domain_name $domain_admin_username $domain_admin_password
            ;;
        'Oracle Linux Server')
            echo "This is an Oracle  machine " >> $logfile
            echo "Downloading the script for Oracle  from github and execute it " >> $logfile
            wget -O oracle.sh https://raw.githubusercontent.com/spalnatik/winbindAD/main/oracle.sh
            chmod +x oracle.sh
            echo "executing the script .." >> $logfile
            ./oracle.sh $domain_name $domain_admin_username $domain_admin_password
            ;;
            *)
            echo "OS release file is there , but it does not match the endoresed distribtion, manual check is needed" >> $logfile
            ;;
    esac
else
    echo "Trying to check if it is centos 6 " >> $logfile
    os_version=`cat /etc/centos-release | grep -o 6`
    if [ $os_version == 6 ]
    then
        echo "it is a Centos 6 machine " >> $logfile
        echo "Downloading and executing its file " >> $logfile
        echo "Installing wget from yum , in case it was not there" >> $logfile
        yum install -y wget
        wget -O centos-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/centos-domain-join.sh
        ./centos-domain-join.sh $domain_name $domain_admin_username $domain_admin_password 
    else
        echo "Trying to check if Oracle 6 machine" >> $logfile
        os_version=`cat /etc/oracle-release | grep -o 6` >> $logfile
        if [ $os_version == 6 ]
        then
            echo "it is a Oracle 6 machine " >> $logfile
            echo "Downloading and executing its file " >> $logfile
            echo "Installing wget from yum , in case it was not there" >> $logfile
            yum install -y wget
            wget -O oracle-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/oracle-domain-join.sh
            ./oracle-domain-join.sh $domain_name $domain_admin_username $domain_admin_password 
        else
            echo "Trying to check if it is Redhat 6 " >> $logfile
            os_version=`cat /etc/redhat-release | grep -o 6`
            if [ $os_version == 6 ]
            then
                echo "it is a Redhat 6 machine " >> $logfile
                echo "Downloading and executing its file " >> $logfile
                echo "Installing wget from yum , in case it was not there" >> $logfile
                yum install -y wget
                wget -O rhel-domain-join.sh https://raw.githubusercontent.com/imabedalghafer/domain-repro/master/rhel-domain-join.sh
                ./rhel-domain-join.sh $domain_name $domain_admin_username $domain_admin_password 
            else
                echo "Not able to determine the version , manual check is needed .." >> $logfile
                exit 4  
            fi
        fi
    fi
fi
