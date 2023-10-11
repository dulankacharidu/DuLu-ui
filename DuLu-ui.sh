#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Error: This script must be run as root!\n" && exit 1

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
    LOGE "System version not detected, please contact the script author！\n" && exit 1
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
        LOGE "Please use CentOS 7 or higher system！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Please use Ubuntu 16 or higher system！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Please use Debian 8 or higher version of the system！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart the panel, restarting the panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/dulankacharidu/DuLu-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force reinstall the latest version without losing data. Do you want to continue??" "n"
    if [[ $? != 0 ]]; then
        LOGE "Cancelled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/dulankacharidu/DuLu-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "The update is completed and the panel has been automatically restarted. "
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel? Xray will also be uninstalled.
?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop DuLu-ui
    systemctl disable DuLu-ui
    rm /etc/systemd/system/DuLu-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/DuLu-ui/ -rf
    rm /usr/local/DuLu-ui/ -rf

    echo ""
    echo -e "The uninstallation is successful. If you want to delete this script, run ${green}rm /usr/bin/DuLu-ui -f${plain} after exiting the script to delete it."
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset your username and password to admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/DuLu-ui/DuLu-ui setting -username admin -password admin
    echo -e "The username and password have been reset to ${green}admin${plain}, please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings? Account data will not be lost and username and password will not be changed." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/DuLu-ui/DuLu-ui setting -reset
    echo -e "All panel settings have been reset to default, now please restart the panel and access the panel using the default ${green}54321${plain} port"
    confirm_restart
}

check_config() {
    info=$(/usr/local/DuLu-ui/DuLu-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Enter port number[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Cancelled"
        before_show_menu
    else
        /usr/local/DuLu-ui/DuLu-ui setting -port ${port}
        echo -e "After setting the port, please restart the panel now and use the newly set port ${green}${port}${plain} to access the panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "The panel is already running and does not need to be started again. If you need to restart, please select Restart."
    else
        systemctl start DuLu-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "DuLu-ui Started successfully"
        else
            LOGE "The panel failed to start. It may be because the startup time exceeded two seconds. Please check the log information later."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "The panel has been stopped and does not need to be stopped again
"
    else
        systemctl stop DuLu-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "DuLu-ui and xray stopped successfully"
        else
            LOGE "The panel failed to stop, possibly because the stop time exceeded two seconds. Please check the log information later."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart DuLu-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "DuLu-ui and xray restarted successfully"
    else
        LOGE "The panel restart failed, possibly because the startup time exceeded two seconds. Please check the log information later."
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status DuLu-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable DuLu-ui
    if [[ $? == 0 ]]; then
        LOGI "DuLu-ui Setup auto-start at power on successfully
"
    else
        LOGE "DuLu-ui Failed to set up auto-start at power on"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable DuLu-ui
    if [[ $? == 0 ]]; then
        LOGI "DuLu-ui Cancel boot and auto-start successfully"
    else
        LOGE "DuLu-ui Cancel boot auto-start failure"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u DuLu-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/DuLu-ui/DuLu-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/DuLu-ui -N --no-check-certificate https://github.com/dulankacharidu/DuLu-ui/raw/master/DuLu-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Download script failed, please check whether the machine can connect Github"
        before_show_menu
    else
        chmod +x /usr/bin/DuLu-ui
        LOGI "The upgrade script is successful, please re-run the script." && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/DuLu-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status DuLu-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled DuLu-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "The panel has been installed, please do not install it again"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Please install the panel first"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Panel status: ${green} is running ${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Panel status: ${yellow} is not running ${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Panel status: ${red} is not installed ${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether it starts automatically at boot: ${green} is ${plain}"
    else
        echo -e "Whether to start automatically at boot: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green} running ${plain}"
    else
        echo -e "xray status: ${red} is not running ${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
   LOGD "******Instructions for use******"
    LOGI "This script will use Acme script to apply for a certificate. Please ensure:"
    LOGI "1. Know the Cloudflare registration email"
    LOGI "2. Know Cloudflare Global API Key"
    LOGI "3. The domain name has been resolved to the current server through Cloudflare"
    LOGI "4. The default installation path for this script to apply for a certificate is the /root/cert directory"
    confirm "I have confirmed the above content [y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Install Acme Script"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Failed to install acme script"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
       LOGD "Please set domain name:"
        read -p "Input your domain here:" CF_Domain
        LOGD "Your domain name is set to:${CF_Domain}"
        LOGD "Please set API key:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "Your API key is: ${CF_GlobalKey}"
        LOGD "Please set up your registration email:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "Your registered email is:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Failed to modify the default CA to Lets'Encrypt and the script exited"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
       if [ $? -ne 0 ]; then
            LOGE "Certificate signing failed, script exited"
            exit 1
        else
            LOGI "Certificate issued successfully, installing..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Certificate installation failed, script exited"
            exit 1
        else
            LOGI "Certificate installed successfully, automatic update enabled..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Automatic update setting failed, script exited"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "The certificate has been installed and automatic update has been turned on. The detailed information is as follows"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "How to use DuLu-ui management script: "
    echo "---------------------------------------------"
    echo "DuLu-ui - Show management menu (more functions)"
    echo "DuLu-ui start - start DuLu-ui panel"
    echo "DuLu-ui stop - Stop DuLu-ui panel"
    echo "DuLu-ui restart - Restart the DuLu-ui panel"
    echo "DuLu-ui status - View DuLu-ui status"
    echo "DuLu-ui enable - Set DuLu-ui to start automatically at boot"
    echo "DuLu-ui disable - Cancel DuLu-ui startup at boot"
    echo "DuLu-ui log - View DuLu-ui log"
    echo "DuLu-ui v2-ui - migrate the v2-ui account data of this machine to DuLu-ui"
    echo "DuLu-ui update - update DuLu-ui panel"
    echo "DuLu-ui install - install DuLu-ui panel"
    echo "DuLu-ui uninstall - Uninstall DuLu-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}DuLu-ui panel management script${plain}
  ${green}0.${plain} exit script
————————————————
  ${green}1.${plain} Install DuLu-ui
  ${green}2.${plain} update DuLu-ui
  ${green}3.${plain} Uninstall DuLu-ui
————————————————
  ${green}4.${plain} Reset username and password
  ${green}5.${plain} Reset panel settings
  ${green}6.${plain} Set panel port
  ${green}7.${plain} View current panel settings
————————————————
  ${green}8.${plain} Start DuLu-ui
  ${green}9.${plain} stop DuLu-ui
  ${green}10.${plain} Restart DuLu-ui
  ${green}11.${plain} View DuLu-ui status
  ${green}12.${plain} View DuLu-ui log
————————————————
  ${green}13.${plain} Set DuLu-ui to start automatically at boot
  ${green}14.${plain} Cancel DuLu-ui auto-start at boot
————————————————
  ${green}15.${plain} One-click installation of bbr (latest kernel)
  ${green}16.${plain} One-click application for SSL certificate (acme application)
 "
    show_status
    echo && read -p "Please enter selection [0-16]: " num
    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Please enter the correct number [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
