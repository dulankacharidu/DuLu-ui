#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Mistake：${plain} This script must be run as root user！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Failed to detect architecture, use default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64). If the detection is incorrect, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}please use CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${redPlease use Debian 8 or higher version of the system！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed DuLu-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, you need to forcefully change the port and account password after the installation/update is completed.${plain}"
    read -p "Confirm whether to continue?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Please set the panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow} Confirm settings, setting ${plain}"
        /usr/local/DuLu-ui/DuLu-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow} account password setting completed${plain}"
        /usr/local/DuLu-ui/DuLu-ui setting -port ${config_port}
        echo -e "${yellow} panel port setting completed${plain}"
    else
        echo -e "${red} has been cancelled, all settings are default settings, please modify ${plain} in time"
    fi
}

install_DuLu-ui() {
    systemctl stop DuLu-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/dulankacharidu/DuLu-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect the DuLu-ui version. It may be that the Github API limit is exceeded. Please try again later, or manually specify the DuLu-ui version for installation.${plain}"
            exit 1
        fi
        echo -e "The latest version of Dulu-ui detected: ${last_version}, start installation"
        wget -N --no-check-certificate -O /usr/local/Dulu-ui-linux-${arch}.tar.gz https://github.com/dulakacharidu/Dulu-ui/releases/download/${last_version}/Dulu-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download Dulu-ui, please make sure your server can download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/dulankacharidu/DuLu-ui/releases/download/${last_version}/DuLu-ui-linux-${arch}.tar.gz"
        echo -e "start installation Dulu-ui v$1"
        wget -N --no-check-certificate -O /usr/local/Dulu-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download Dulu-ui v$1 failed, please make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/Dulu-ui/ ]]; then
        rm /usr/local/Dulu-ui/ -rf
    fi

    tar zxvf Dulu-ui-linux-${arch}.tar.gz
    rm Dulu-ui-linux-${arch}.tar.gz -f
    cd Dulu-ui
    chmod +x Dulu-ui bin/xray-linux-${arch}
    cp -f Dulu-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/Dulu-ui https://raw.githubusercontent.com/dulankacharidu/Dulu-ui/main/Dulu-ui.sh
    chmod +x /usr/local/Dulu-ui/Dulu-ui.sh
    chmod +x /usr/bin/Dulu-ui
    config_after_install
    #echo -e "If it is a new installation, the default web port is ${green}54321${plain}, and the default username and password are ${green}admin${plain}"
    #echo -e "Please ensure that this port is not occupied by other programs, ${yellow} and ensure that port 54321 has been released ${plain}"
    # echo -e "If you want to change 54321 to another port, enter the Dulu-ui command to modify it. Also make sure that the port you modify is also allowed."
    #echo -e ""
    #echo -e "If updating the panel, access the panel as you did before"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable Dulu-ui
    systemctl start Dulu-ui
    echo -e "${green}Dulu-ui v${last_version}${plain} installation is complete and the panel has been started,"
    echo -e ""
    echo -e "How to use Dulu-ui management script: "
    echo -e "------------------------------------------------- "
    echo -e "Dulu-ui - show management menu (more functions)"
    echo -e "Dulu-ui start - Start Dulu-ui panel"
    echo -e "Dulu-ui stop - Stop Dulu-ui panel"
    echo -e "Dulu-ui restart - Restart the Dulu-ui panel"
    echo -e "Dulu-ui status - View Dulu-ui status"
    echo -e "Dulu-ui enable - Set Dulu-ui to start automatically at boot"
    echo -e "Dulu-ui disable - Cancel Dulu-ui startup at boot"
    echo -e "Dulu-ui log - View Dulu-ui log"
    echo -e "Dulu-ui v2-ui - migrate the v2-ui account data of this machine to Dulu-ui"
    echo -e "Dulu-ui update - update Dulu-ui panel"
    echo -e "Dulu-ui install - install Dulu-ui panel"
    echo -e "Dulu-ui uninstall - Uninstall Dulu-ui panel"
    echo -e "------------------------------------------------- "
}

echo -e "${green} starts installing ${plain}"
install_base
install_Dulu-ui $1
