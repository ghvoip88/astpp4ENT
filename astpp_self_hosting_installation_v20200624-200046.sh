#!/bin/bash

#################################
##########  variables ###########
#################################

#General Congifuration
TEMP_USER_ANSWER="no"
ASTPP_SOURCE_DIR=/opt/ASTPP
ASTPP_HOST_DOMAIN_NAME="host.domain.tld"
IS_ENTERPRISE="True"

#ASTPP Configuration
ASTPPDIR=/var/lib/astpp/
ASTPPEXECDIR=/usr/local/astpp/
ASTPPLOGDIR=/var/log/astpp/

#Freeswich Configuration
FS_DIR=/usr/share/freeswitch
FS_SOUNDSDIR=${FS_DIR}/sounds/en/us/callie

#HTML and Mysql Configuraition
WWWDIR=/var/www/html
ASTPP_DATABASE_NAME="astpp"
ASTPP_DB_USER="astppuser"

#################################
####  general functions #########
#################################

#Generate random password
genpasswd() 
{
        length=$1
        digits=({1..9})
        lower=({a..z})
        upper=({A..Z})
        CharArray=(${digits[*]} ${lower[*]} ${upper[*]})
        ArrayLength=${#CharArray[*]}
        password=""
        for i in `seq 1 $length`
        do
                index=$(($RANDOM%$ArrayLength))
                char=${CharArray[$index]}
                password=${password}${char}
        done
        echo $password
}

#DEFAULT PASSWORD CHANGE
defpass=`tr -cd \#_[:alnum:] < /dev/urandom |  fold -w 12 | head -1`
FS_EVENT_SOCKET=$(genpasswd 20)
sleep 1s
MYSQL_ROOT_PASSWORD=`echo "$(genpasswd 20)" | sed s/./*/5`
ASTPPUSER_MYSQL_PASSWORD=`echo "$(genpasswd 20)" | sed s/./*/5`
#Fetch OS Distribution
get_linux_distribution ()
{ 
        V1=`cat /etc/*release | head -n1 | tail -n1 | cut -c 14- | cut -c1-18`
        V2=`cat /etc/*release | head -n7 | tail -n1 | cut -c 14- | cut -c1-14`
        V3=`cat /etc/*release | head -n1 | tail -n1 | cut -c 14- | cut -c1-19`
        if [[ $V1 = "Debian GNU/Linux 9" ]]; then
                DIST="DEBIAN"
        else if [[ $V2 = "CentOS Linux 7" ]]; then
                DIST="CENTOS"
        else if [[ $V3 = "Debian GNU/Linux 10" ]]; then
                DIST="DEBIAN10"
        else
                DIST="OTHER"
                echo -e 'Ooops!!! Quick Installation does not support your distribution \nPlease use manual steps or contact ASTPP Sales Team \nat sales@astpp.com.'
                exit 1
        fi
        fi
        fi
}

#Install Prerequisties
install_prerequisties ()
{
        if [ $DIST = "CENTOS" ]; then
                systemctl stop httpd
                systemctl disable httpd
                yum update -y
                yum install -y wget curl git bind-utils ntpdate systemd net-tools whois sendmail sendmail-cf mlocate vim ImageMagick
                
        elif [ $DIST = "DEBIAN" ]; then
                apt update
                apt install -y wget curl git dnsutils ntpdate systemd net-tools whois sendmail-bin sensible-mda mlocate vim imagemagick

        elif [ $DIST = "DEBIAN10" ]; then
                apt update
                apt install -y wget curl git dnsutils ntpdate systemd net-tools whois sendmail-bin sensible-mda mlocate vim imagemagick
        fi
        sleep 1s
        cd /usr/src/
        wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
        tar -xzvf ioncube_loaders_lin_x86-64.tar.gz
        cd ioncube
}

#Fetch ASTPP Source
get_astpp_source ()
{
        cd /opt
        wget http://dl.astppbilling.org:9843/ASTPP.tar.gz
        tar -xzvf ASTPP.tar.gz
        /bin/chmod -Rf 777 /opt/ASTPP
        cd ASTPP
	if [ $DIST = "CENTOS" ]; then
		cp -rf freeswitch/scripts_cent7 freeswitch/scripts
		cp -rf web_interface/astpp/addons/Enterprise_cent7 web_interface/astpp/addons/Enterprise
	elif [ $DIST = "DEBIAN" ]; then 
		cp -rf freeswitch/scripts_deb9 freeswitch/scripts
		cp -rf web_interface/astpp/addons/Enterprise_deb9 web_interface/astpp/addons/Enterprise		
	elif [ $DIST = "DEBIAN10" ]; then
		cp -rf freeswitch/scripts_deb9 freeswitch/scripts
		cp -rf web_interface/astpp/addons/Enterprise_deb9 web_interface/astpp/addons/Enterprise
	fi
}

#License Acceptence
license_accept ()
{
        cd /usr/src
        if [ $IS_ENTERPRISE = "True" ]; then
                echo ""
        fi
        if [ $IS_ENTERPRISE = "False" ]; then
                #clear
                echo "********************"
                echo "License acceptance"
                echo "********************"
                if [ -f LICENSE ]; then
                        more LICENSE
                else
                        wget --no-check-certificate -q -O GNU-AGPLv4.0.txt https://raw.githubusercontent.com/iNextrix/ASTPP/master/LICENSE
                        more GNU-AGPLv4.0.txt
                fi
                echo "***"
                echo "*** I agree to be bound by the terms of the license - [YES/NO]"
                echo "*** " 
                read ACCEPT
                while [ "$ACCEPT" != "yes" ] && [ "$ACCEPT" != "Yes" ] && [ "$ACCEPT" != "YES" ] && [ "$ACCEPT" != "no" ] && [ "$ACCEPT" != "No" ] && [ "$ACCEPT" != "NO" ]; do
                        echo "I agree to be bound by the terms of the license - [YES/NO]"
                        read ACCEPT
                done
                if [ "$ACCEPT" != "yes" ] && [ "$ACCEPT" != "Yes" ] && [ "$ACCEPT" != "YES" ]; then
                        echo "Ooops!!! License rejected!"
                        LICENSE_VALID=False
                        exit 0
                else
                        echo "Hey!!! Licence accepted!"
                        LICENSE_VALID=True
                fi
        fi
}

#Install PHP
install_php ()
{
        cd /usr/src
        if [ "$DIST" = "DEBIAN" ]; then
                apt -y install lsb-release apt-transport-https ca-certificates 
                wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.3.list
                apt-get update
                apt install -y php7.3 php7.3-fpm php7.3-mysql php7.3-cli php7.3-json php7.3-readline php7.3-xml php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-opcache php7.3-imap php-pear php-imagick
                systemctl stop apache2
                systemctl disable apache2
        else if [ "$DIST" = "CENTOS" ]; then
                yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm 
                yum -y install epel-release yum-utils
                yum-config-manager --disable remi-php54
                yum-config-manager --enable remi-php73
                yum install -y php php-fpm php-mysql php-cli php-json php-readline php-xml php-curl php-gd php-json php-mbstring php-opcache php-imap php-pear php-imagick
                systemctl stop httpd
                systemctl disable httpd

        else if [ "$DIST" = "DEBIAN10" ]; then
                apt -y install lsb-release apt-transport-https ca-certificates
                wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.3.list
                apt-get update
                apt install -y php7.3 php7.3-fpm php7.3-mysql php7.3-cli php7.3-json php7.3-readline php7.3-xml php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-opcache php7.3-imap php-pear php-imagick
                systemctl stop apache2
                systemctl disable apache2
        fi
        fi
        fi 
}

#Install Mysql
install_mysql ()
{
        cd /usr/src
        if [ "$DIST" = "DEBIAN" ]; then
                        apt-get install software-properties-common -y
                wget https://repo.mysql.com/mysql-apt-config_0.8.13-1_all.deb
                apt install ./mysql-apt-config_0.8.13-1_all.deb
                apt update
                apt -y install unixodbc unixodbc-bin
                debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)"
                DEBIAN_FRONTEND=noninteractive apt install -y mysql-server
                wget https://cdn.mysql.com//Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.18-linux-debian9-x86-64bit.tar.gz
                tar -xzvf  mysql-connector-odbc-8.0.18-linux-debian9-x86-64bit.tar.gz
                cd /usr/src/mysql-connector-odbc-8.0.18-linux-debian9-x86-64bit/
                cp -rf lib/libmyodbc8* /usr/lib/x86_64-linux-gnu/odbc/.
        else if [ "$DIST" = "CENTOS" ]; then
                wget https://repo.mysql.com/mysql80-community-release-el7-1.noarch.rpm
                yum localinstall -y mysql80-community-release-el7-1.noarch.rpm
                yum install -y mysql-community-server unixODBC mysql-connector-odbc
                systemctl start mysqld
                MYSQL_ROOT_TEMP=$(grep 'temporary password' /var/log/mysqld.log | cut -c 14- | cut -c100-111 2>&1)
                mysql -uroot -p${MYSQL_ROOT_TEMP} --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';FLUSH PRIVILEGES;"

        else if [ "$DIST" = "DEBIAN10" ]; then
                        apt-get install software-properties-common -y
                wget https://repo.mysql.com/mysql-apt-config_0.8.13-1_all.deb
                apt install ./mysql-apt-config_0.8.13-1_all.deb
                apt update
                apt -y install unixodbc unixodbc-bin
                debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)"
                DEBIAN_FRONTEND=noninteractive apt install -y mysql-server
                wget https://cdn.mysql.com//Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.18-linux-debian9-x86-64bit.tar.gz
                tar -xzvf  mysql-connector-odbc-8.0.18-linux-debian9-x86-64bit.tar.gz
                cd /usr/src/mysql-connector-odbc-8.0.18-linux-debian9-x86-64bit/
                cp -rf lib/libmyodbc8* /usr/lib/x86_64-linux-gnu/odbc/.

        fi
        fi
        fi
        echo ""
        echo "MySQL password set to '${MYSQL_ROOT_PASSWORD}'. Remember to delete ~/.mysql_passwd" >> ~/.mysql_passwd
        echo "" >>  ~/.mysql_passwd
        echo "MySQL astppuser password:  ${ASTPPUSER_MYSQL_PASSWORD} " >>  ~/.mysql_passwd
        chmod 400 ~/.mysql_passwd
}

#Normalize mysql installation
normalize_mysql ()
{
        if [ ${DIST} = "DEBIAN" ]; then
                cp ${ASTPP_SOURCE_DIR}/misc/odbc/deb_odbc.ini /etc/odbc.ini
                sed -i '33i wait_timeout=600' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i interactive_timeout = 600' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i sql_mode=""' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i log_bin_trust_function_creators = 1' /etc/mysql/mysql.conf.d/mysqld.cnf
                systemctl restart mysql
                systemctl enable mysql
        elif  [ ${DIST} = "DEBIAN10" ]; then
                cp ${ASTPP_SOURCE_DIR}/misc/odbc/deb_odbc.ini /etc/odbc.ini
                sed -i '33i wait_timeout=600' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i interactive_timeout = 600' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i sql_mode=""' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i log_bin_trust_function_creators = 1' /etc/mysql/mysql.conf.d/mysqld.cnf
                systemctl restart mysql
                systemctl enable mysql
        elif  [ ${DIST} = "CENTOS" ]; then
                systemctl start mysqld
                systemctl enable mysqld
                cp ${ASTPP_SOURCE_DIR}/misc/odbc/cent_odbc.ini /etc/odbc.ini
                sed -i '26i wait_timeout=600' /etc/my.cnf
                sed -i '26i interactive_timeout = 600' /etc/my.cnf
                sed -i '26i sql-mode=""' /etc/my.cnf
                sed -i '26i log_bin_trust_function_creators = 1' /etc/my.cnf
                systemctl restart mysqld
                systemctl enable mysqld
        fi
}

#User Response Gathering
get_user_response ()
{
        echo ""
        read -p "Enter FQDN example (i.e ${ASTPP_HOST_DOMAIN_NAME}): "
        ASTPP_HOST_DOMAIN_NAME=${REPLY}
        echo "Your entered FQDN is : ${ASTPP_HOST_DOMAIN_NAME} "
        echo ""
        read -p "Enter your email address: ${EMAIL}"
        EMAIL=${REPLY}
        read -n 1 -p "Press any key to continue ... "
        NAT1=$(dig +short myip.opendns.com @resolver1.opendns.com)
        NAT2=$(curl http://ip-api.com/json/)
        INTF=$(ifconfig $1|sed -n 2p|awk '{ print $2 }'|awk -F : '{ print $2 }')
        if [ "${NAT1}" != "${INTF}" ]; then
                echo "Server is behind NAT";
                NAT="True"
        fi
        curl --data "email=$EMAIL" --data "data=$NAT2" --data "type=Install" http://astppbilling.org/lib/
}

#Install ASTPP with dependencies
install_astpp ()
{
        if [ ${DIST} = "DEBIAN" ]; then
                echo "Installing dependencies for ASTPP"
                apt update
                apt install -y nginx ntpdate ntp lua5.1 bc libxml2 libxml2-dev openssl libcurl4-openssl-dev gettext gcc g++
                echo "Installing dependencies for ASTPP"
        elif  [ ${DIST} = "DEBIAN10" ]; then
                echo "Installing dependencies for ASTPP"
                apt update
                apt install -y nginx ntpdate ntp lua5.1 bc libxml2 libxml2-dev openssl libcurl4-openssl-dev gettext gcc g++
                echo "Installing dependencies for ASTPP"
        elif  [ ${DIST} = "CENTOS" ]; then
                echo "Installing dependencies for ASTPP"
                yum install -y nginx libxml2 libxml2-devel openssl openssl-devel gettext-devel fileutils gcc-c++
        fi
        echo "Creating neccessary locations and configuration files ..."
        mkdir -p ${ASTPPDIR}
        mkdir -p ${ASTPPLOGDIR}
        mkdir -p ${ASTPPEXECDIR}
        mkdir -p ${WWWDIR}
        cp -rf ${ASTPP_SOURCE_DIR}/config/astpp-config.conf ${ASTPPDIR}astpp-config.conf
        cp -rf ${ASTPP_SOURCE_DIR}/config/astpp.lua ${ASTPPDIR}astpp.lua
        ln -s ${ASTPP_SOURCE_DIR}/web_interface/astpp ${WWWDIR}
        ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
        sleep 2s
        sed -i 's/PRIVATE_KEY = <PR_KEY>/PRIVATE_KEY = "8YSDaBtDHAB3EQkxPAyTz2I5DttzA9uR"/' /var/lib/astpp/astpp-config.conf
                sed -i 's/ENCRYPTION_KEY = <EN_KEY>/ENCRYPTION_KEY = "r)fddEw232f"/' /var/lib/astpp/astpp-config.conf
}

#Normalize astpp installation
normalize_astpp ()
{
        mkdir -p /etc/nginx/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
        pecl install imagick
        if [ ${DIST} = "DEBIAN" ]; then
                /bin/cp /usr/src/ioncube/ioncube_loader_lin_7.3.so /usr/lib/php/20180731/
                sed -i '2i zend_extension ="/usr/lib/php/20180731/ioncube_loader_lin_7.3.so"' /etc/php/7.3/fpm/php.ini
                sed -i '2i zend_extension ="/usr/lib/php/20180731/ioncube_loader_lin_7.3.so"' /etc/php/7.3/cli/php.ini
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_astpp.conf /etc/nginx/conf.d/astpp.conf
                systemctl start nginx
                systemctl enable nginx
                systemctl start php7.3-fpm
                systemctl enable php7.3-fpm
                chown -Rf root.root ${ASTPPDIR}
                chown -Rf www-data.www-data ${ASTPPLOGDIR}
                chown -Rf root.root ${ASTPPEXECDIR}
                chown -Rf www-data.www-data ${WWWDIR}/astpp
                chown -Rf www-data.www-data ${ASTPP_SOURCE_DIR}/web_interface/astpp
                chmod -Rf 755 ${WWWDIR}/astpp     
                sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php/7.3/fpm/pool.d/www.conf
                sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php/7.3/fpm/php.ini
                sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php/7.3/fpm/php.ini
                sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php/7.3/fpm/php.ini
                sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php/7.3/fpm/php.ini
                sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php/7.3/fpm/php.ini
                sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.3/fpm/php.ini
                systemctl restart php7.3-fpm
                CRONPATH='/var/spool/cron/crontabs/astpp'
                echo "# Change owner of recording directory 
                * * * * * /bin/chown -Rf www-data.www-data /var/lib/freeswitch/recordings/
                # Modify the recording files permission
                * * * * * /bin/chmod 777 -Rf /var/lib/freeswitch/recordings/
                # reloading sofia module after 10 seconds of every reboot to get the profile loaded correctly
                @reboot /bin/sleep 10 && /usr/bin/fs_cli -p$FS_EVENT_SOCKET -x'reload mod_sofia'
                " > $CRONPATH


        elif  [ ${DIST} = "DEBIAN10" ]; then
                /bin/cp /usr/src/ioncube/ioncube_loader_lin_7.3.so /usr/lib/php/20180731/
                sed -i '2i zend_extension ="/usr/lib/php/20180731/ioncube_loader_lin_7.3.so"' /etc/php/7.3/fpm/php.ini
                sed -i '2i zend_extension ="/usr/lib/php/20180731/ioncube_loader_lin_7.3.so"' /etc/php/7.3/cli/php.ini
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_astpp.conf /etc/nginx/conf.d/astpp.conf
                systemctl start nginx
                systemctl enable nginx
                systemctl start php7.3-fpm
                systemctl enable php7.3-fpm
                chown -Rf root.root ${ASTPPDIR}
                chown -Rf www-data.www-data ${ASTPPLOGDIR}
                chown -Rf root.root ${ASTPPEXECDIR}
                chown -Rf www-data.www-data ${WWWDIR}/astpp
                chown -Rf www-data.www-data ${ASTPP_SOURCE_DIR}/web_interface/astpp
                chmod -Rf 755 ${WWWDIR}/astpp
                sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php/7.3/fpm/pool.d/www.conf
                sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php/7.3/fpm/php.ini
                sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php/7.3/fpm/php.ini
                sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php/7.3/fpm/php.ini
                sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php/7.3/fpm/php.ini
                sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php/7.3/fpm/php.ini
                sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.3/fpm/php.ini
                systemctl restart php7.3-fpm
                CRONPATH='/var/spool/cron/crontabs/astpp'
                echo "# Change owner of recording directory
                * * * * * /bin/chown -Rf www-data.www-data /var/lib/freeswitch/recordings/
                # Modify the recording files permission
                * * * * * /bin/chmod 777 -Rf /var/lib/freeswitch/recordings/
                # reloading sofia module after 10 seconds of every reboot to get the profile loaded correctly
                @reboot /bin/sleep 10 && /usr/bin/fs_cli -p$FS_EVENT_SOCKET -x'reload mod_sofia'
                " > $CRONPATH


        elif  [ ${DIST} = "CENTOS" ]; then
                cp /usr/src/ioncube/ioncube_loader_lin_7.3.so /usr/lib64/php/modules/
                sed -i '2i zend_extension ="/usr/lib64/php/modules/ioncube_loader_lin_7.3.so"' /etc/php.ini
                cp ${ASTPP_SOURCE_DIR}/web_interface/nginx/cent_astpp.conf /etc/nginx/conf.d/astpp.conf
                setenforce 0
                systemctl start nginx
                systemctl enable nginx
                systemctl start php-fpm
                systemctl enable php-fpm
                systemctl stop firewalld
                systemctl disable firewalld
                chown -Rf root.root ${ASTPPDIR}
                chown -Rf apache.apache ${ASTPPLOGDIR}
                chown -Rf root.root ${ASTPPEXECDIR}
                chown -Rf apache.apache ${WWWDIR}/astpp
                chown -Rf apache.apache ${ASTPP_SOURCE_DIR}/web_interface/astpp
                chmod -Rf 755 ${WWWDIR}/astpp
                sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php-fpm.d/www.conf
                sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php.ini
                sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php.ini
                sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php.ini
                sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php.ini
                sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php.ini
                sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php.ini
                systemctl restart php-fpm
                CRONPATH='/var/spool/cron/astpp'
                echo "# Change owner of recording directory 
                * * * * * /usr/bin/chown -Rf apache.apache /var/lib/freeswitch/recordings/
                # Modify the recording files permission
                * * * * * /usr/bin/chmod 777 -Rf /var/lib/freeswitch/recordings/
                # reloading sofia module after 10 seconds of every reboot to get the profile loaded correctly
                @reboot /usr/bin/sleep 10 && /usr/bin/$FS_EVENT_SOCKET -pClueCon -x'reload mod_sofia'
                " > $CRONPATH
        fi
        echo "# To call all crons   
                * * * * * cd ${ASTPP_SOURCE_DIR}/web_interface/astpp/cron/ && php cron.php crons
                # At every day 1 AM server time, freeswitch logs will be removed older then 21 days
                0 1 * * * /usr/bin/find /var/log/freeswitch/log/ -mindepth 0 -mtime +21 -exec rm {} \;
                " >> $CRONPATH
                chmod 600 $CRONPATH
                crontab $CRONPATH
        touch /var/log/astpp/astpp.log
        touch /var/log/astpp/astpp_email.log
        chmod 777 /var/log/astpp/astpp.log
        chmod 777 /var/log/astpp/astpp_email.log
        chmod -Rf 777 ${ASTPP_SOURCE_DIR}/web_interface/astpp/assets/
        sed -i "s#dbpass = <PASSSWORD>#dbpass = ${ASTPPUSER_MYSQL_PASSWORD}#g" ${ASTPPDIR}astpp-config.conf
        sed -i "s#DB_PASSWD=\"<PASSSWORD>\"#DB_PASSWD = \"${ASTPPUSER_MYSQL_PASSWORD}\"#g" ${ASTPPDIR}astpp.lua
        sed -i "s#base_url=http://localhost:8089/#base_url=https://${ASTPP_HOST_DOMAIN_NAME}/#g" ${ASTPPDIR}/astpp-config.conf
        sed -i "s#PASSWORD = <PASSWORD>#PASSWORD = ${ASTPPUSER_MYSQL_PASSWORD}#g" /etc/odbc.ini
        systemctl restart nginx
}

#Install freeswitch with dependencies
install_freeswitch ()
{
        if [ ${DIST} = "DEBIAN" ]; then
                #clear
                echo "Installing FREESWITCH"
                sleep 5
                apt-get install -y gnupg2
                wget -O - https://files.freeswitch.org/repo/deb/freeswitch-1.8/fsstretch-archive-keyring.asc | apt-key add -
                echo "deb http://files.freeswitch.org/repo/deb/freeswitch-1.8/ stretch main" > /etc/apt/sources.list.d/freeswitch.list
                echo "deb-src http://files.freeswitch.org/repo/deb/freeswitch-1.8/ stretch main" >> /etc/apt/sources.list.d/freeswitch.list
                apt-get update -y 
                sleep 2s
                apt-get install -y freeswitch-meta-all
                mv -f ${FS_DIR}/scripts /tmp/.
                ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
                ln -s ${ASTPP_SOURCE_DIR}/freeswitch/scripts_deb9 ${FS_DIR}/scripts
                cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/sounds/*.wav ${FS_SOUNDSDIR}/
                cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/conf/autoload_configs/* /etc/freeswitch/autoload_configs/
                chmod -Rf 777 /var/www/html/fs/
                chmod -Rf 777 /opt/ASTPP/
                echo "FREESWITCH installed successfully. . ."

        elif  [ ${DIST} = "DEBIAN10" ]; then
                echo "Installing FREESWITCH"
                sleep 5
                apt-get update && apt-get install -y gnupg2 wget lsb-release
                wget -O - https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | apt-key add -
 
                echo "deb http://files.freeswitch.org/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list
                echo "deb-src http://files.freeswitch.org/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list
                apt-get update -y
                sleep 1s
                apt-get install freeswitch-meta-all -y
                mv -f ${FS_DIR}/scripts /tmp/.
                ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
                ln -s ${ASTPP_SOURCE_DIR}/freeswitch/scripts_deb9 ${FS_DIR}/scripts
                cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/sounds/*.wav ${FS_SOUNDSDIR}/
                cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/conf/autoload_configs/* /etc/freeswitch/autoload_configs/


        elif  [ ${DIST} = "CENTOS" ]; then
                #clear
                sleep 5
                echo "Installing FREESWITCH"
                yum install -y http://files.freeswitch.org/freeswitch-release-1-6.noarch.rpm epel-release deltarpm
                yum install -y freeswitch-config-vanilla freeswitch-lang-* freeswitch-sounds-* freeswitch-xml-curl freeswitch-event-json-cdr freeswitch-lua
                mv -f ${FS_DIR}/scripts /tmp/.
                ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
                ln -s ${ASTPP_SOURCE_DIR}/freeswitch/scripts_cent7 ${FS_DIR}/scripts

                cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/sounds/*.wav ${FS_SOUNDSDIR}/
                cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/conf/autoload_configs/* /etc/freeswitch/autoload_configs/

                echo "FREESWITCH installed successfully. . ."
        fi

}

#Normalize freeswitch installation
normalize_freeswitch ()
{
        systemctl start freeswitch
        systemctl enable freeswitch
        sed -i "s#max-sessions\" value=\"1000#max-sessions\" value=\"2000#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#sessions-per-second\" value=\"30#sessions-per-second\" value=\"50#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#max-db-handles\" value=\"50#max-db-handles\" value=\"500#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#db-handle-timeout\" value=\"10#db-handle-timeout\" value=\"30#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#<\!--     <load module=\"mod_conference\"/> -->#     <load module=\"mod_conference\"/>#g" /etc/freeswitch/autoload_configs/modules.conf.xml
        sed -i "s#<\!--     <load module=\"mod_fifo\"/> -->#     <load module=\"mod_fifo\"/>#g" /etc/freeswitch/autoload_configs/modules.conf.xml
        sed -i '26i <load module=\"mod_spy\"/>' /etc/freeswitch/autoload_configs/modules.conf.xml
        sed -i '26i <load module=\"mod_spandsp\"/>' /etc/freeswitch/autoload_configs/modules.conf.xml
	sed -i '26i <load module=\"mod_curl\"/>' /etc/freeswitch/autoload_configs/modules.conf.xml
        sed -i -e "s/ClueCon/$FS_EVENT_SOCKET/g" /etc/freeswitch/autoload_configs/event_socket.conf.xml
        sleep 1s
        /bin/systemctl restart freeswitch

        rm -rf  /etc/freeswitch/dialplan/*
        touch /etc/freeswitch/dialplan/astpp.xml
        rm -rf  /etc/freeswitch/directory/*
        touch /etc/freeswitch/directory/astpp.xml
        rm -rf  /etc/freeswitch/sip_profiles/*
        touch /etc/freeswitch/sip_profiles/astpp.xml
        chmod -Rf 755 ${FS_SOUNDSDIR}
        if [ ${DIST} = "DEBIAN" ]; then
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_fs.conf /etc/nginx/conf.d/fs.conf
                chown -Rf root.root ${WWWDIR}/fs
                chmod -Rf 755 ${WWWDIR}/fs
                /bin/systemctl restart freeswitch
                /bin/systemctl enable freeswitch

        elif  [ ${DIST} = "DEBIAN10" ]; then
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_fs.conf /etc/nginx/conf.d/fs.conf
                chown -Rf root.root ${WWWDIR}/fs
                chmod -Rf 755 ${WWWDIR}/fs
                /bin/systemctl restart freeswitch
                /bin/systemctl enable freeswitch

        elif  [ ${DIST} = "CENTOS" ]; then
                cp ${ASTPP_SOURCE_DIR}/web_interface/nginx/cent_fs.conf /etc/nginx/conf.d/fs.conf
                chown -Rf root.root ${WWWDIR}/fs
                chmod -Rf 755 ${WWWDIR}/fs
                sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
                sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
                /usr/bin/systemctl restart freeswitch
                /usr/bin/systemctl enable freeswitch
        fi
}

#Install Database for ASTPP
install_database ()
{
        mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} create ${ASTPP_DATABASE_NAME}
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER 'astppuser'@'localhost' IDENTIFIED BY '${ASTPPUSER_MYSQL_PASSWORD}';"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "ALTER USER 'astppuser'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ASTPPUSER_MYSQL_PASSWORD}';"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON \`${ASTPP_DATABASE_NAME}\` . * TO 'astppuser'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"
        sed -i -e "s/ClueCon/$FS_EVENT_SOCKET/g" ${ASTPP_SOURCE_DIR}/database/astpp-4.0.sql
        sed -i -e "s/mfpV9CY|.2gX/$defpass/g" ${ASTPP_SOURCE_DIR}/database/astpp-4.0.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-4.0.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-4.0.1.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-4.0.2.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/20200624.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/api.sql
        #Fetching profiles details from DB and loading them in FS
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/astpp/
        sleep 1s
        /bin/chmod -Rf 777 /opt/ASTPP/
}

#Firewall Configuration
configure_firewall ()
{
        if [ ${DIST} = "DEBIAN" ]; then
                apt install -y firewalld
                systemctl start firewalld
                systemctl enable firewalld
                firewall-cmd --permanent --zone=public --add-service=https
                                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-port=5060/udp
                                firewall-cmd --permanent --zone=public --add-port=5060/tcp
                firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
                firewall-cmd --reload

        elif  [ ${DIST} = "DEBIAN10" ]; then
                                apt install -y firewalld
                systemctl start firewalld
                systemctl enable firewalld
                firewall-cmd --permanent --zone=public --add-service=https
                                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-port=5060/udp
                                firewall-cmd --permanent --zone=public --add-port=5060/tcp
                firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
                firewall-cmd --reload

        elif  [ ${DIST} = "CENTOS" ]; then
                yum install -y firewalld
                systemctl start firewalld
                systemctl enable firewalld
                firewall-cmd --permanent --zone=public --add-service=https
                                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-port=5060/udp
                                firewall-cmd --permanent --zone=public --add-port=5060/tcp
                firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
                firewall-cmd --reload
        fi
}

#Install Fail2ban for security
install_fail2ban()
{
                read -n 1 -p "Do you want to install and configure Fail2ban ? (y/n) "
                if [ "$REPLY"   = "y" ]; then
                        if [ -f /etc/debian_version ] ; then
                            DIST="DEBIAN"
                            sleep 2s
                            apt-get update -y
                            sleep 2s
                            apt-get install fail2ban -y
                            sleep 2s
                            echo ""
                            read -p "Enter Client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /usr/src
                            wget --no-check-certificate --max-redirect=0 https://latest.astppbilling.org/fail2ban_Deb.tar.gz
                            tar xzvf fail2ban_Deb.tar.gz
                            rm -rf /etc/fail2ban
                            cp -rf /usr/src/fail2ban /etc/fail2ban
                            cp -rf ${ASTPP_SOURCE_DIR}/misc/deb9_jail.local /etc/fail2ban/jail.local
                            
                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local
                        
                        elif  [ ${DIST} = "DEBIAN10" ]; then
                            sleep 2s
                            apt-get update -y
                            sleep 2s
                            apt-get install fail2ban -y
                            sleep 2s
                            echo ""
                            read -p "Enter Client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /usr/src
                            wget --no-check-certificate --max-redirect=0 https://latest.astppbilling.org/fail2ban_Deb.tar.gz
                            tar xzvf fail2ban_Deb.tar.gz
                            rm -rf /etc/fail2ban
                            cp -rf /usr/src/fail2ban /etc/fail2ban
                            cp -rf ${ASTPP_SOURCE_DIR}/misc/deb9_jail.local /etc/fail2ban/jail.local

                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local
                                
                        elif [ -f /etc/redhat-release ] ; then
                                DIST="CENTOS"
                            echo "#########################Installing_Fail2ban#####################"                                
                            yum install -y fail2ban
                            echo ""
                            read -p "Enter Client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /usr/src
                            wget --no-check-certificate --max-redirect=0 https://latest.astppbilling.org/fail2ban_Cent.tar.gz
                            tar xzvf fail2ban_Cent.tar.gz
                            rm -rf /etc/fail2ban
                            cp -rf /usr/src/fail2ban /etc/fail2ban
                            cp -rf ${ASTPP_SOURCE_DIR}/misc/cent7_jail.local /etc/fail2ban/jail.local
                            
                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local
                                
                        fi
                        ################################# JAIL.CONF FILE READY ######################
                        echo "################################################################"
                        mkdir /var/run/fail2ban
                        chkconfig fail2ban on
                        sed -i '155d' /etc/fail2ban/jail.conf
                        systemctl stop fail2ban
                        systemctl start fail2ban
                        systemctl enable fail2ban
                        echo "################################################################"
                        echo "Fail2Ban for FreeSwitch & IPtables Integration completed"
                        else
                        echo ""
                        echo "Fail2ban installation is aborted !"
                fi
                        sleep 1s
                        chmod -Rf 777 /opt/ASTPP/freeswitch/fs/
                        sleep 1s
                        chmod -Rf 777 /var/www/html/fs/
                        sleep 1s
                        chmod -Rf 777 /opt/ASTPP/
                        sleep 1s
                        chmod -Rf 777 /var/www/html/fs/
                        sleep 1s
                        chmod -Rf 777 /var/www/html/astpp/
}

#Install Monit for service monitoring
install_monit ()
{
if [ ${DIST} = "DEBIAN" ]; then
apt-get -y install monit
cp ${ASTPP_SOURCE_DIR}/misc/deb9_monitrc /etc/monit/monitrc
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monit/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert on --  $EVENT $SERVICE/   subject: monit alert --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monit/monitrc
sed -i -e 's/## }/ }/g' /etc/monit/monitrc
sleep 1s
systemctl restart monit
systemctl enable monit    

elif [ ${DIST} = "DEBIAN10" ]; then
cd /usr/src/
wget http://ftp.br.debian.org/debian/pool/main/m/monit/monit_5.26.0-1~bpo10+1_amd64.deb
apt install ./monit_5.26.0-1~bpo10+1_amd64.deb
cp ${ASTPP_SOURCE_DIR}/misc/deb9_monitrc /etc/monit/monitrc
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monit/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert on --  $EVENT $SERVICE/   subject: monit alert --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monit/monitrc
sed -i -e 's/## }/ }/g' /etc/monit/monitrc
sleep 1s
systemctl restart monit
systemctl enable monit

elif [ ${DIST} = "CENTOS" ]; then
yum install -y monit
rm -rf /etc/monit.d
rpm --force -Uvh /var/cache/yum/x86_64/7/epel/packages/monit-*.rpm

cp ${ASTPP_SOURCE_DIR}/misc/cent7_monitrc /etc/monitrc
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monitrc
sed -i -e 's/## }/ }/g' /etc/monitrc
sleep 1s
systemctl restart monit
systemctl enable monit    
fi
}

#Configure logrotation for maintain log size
logrotate_install ()
{
if [ ${DIST} = "DEBIAN" ]; then
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/php7.3-fpm
        sed -i -e 's/rotate 12/rotate 5/g' /etc/logrotate.d/php7.3-fpm
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/nginx
        sed -i -e 's/rotate 52/rotate 5/g' /etc/logrotate.d/nginx
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit    
elif [ ${DIST} = "DEBIAN10" ]; then
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/php7.3-fpm
        sed -i -e 's/rotate 12/rotate 5/g' /etc/logrotate.d/php7.3-fpm
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/nginx
        sed -i -e 's/rotate 52/rotate 5/g' /etc/logrotate.d/nginx
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit
elif [ ${DIST} = "CENTOS" ]; then
        sed -i '7 i size 30M' /etc/logrotate.d/syslog
        sed -i '7 i rotate 5' /etc/logrotate.d/syslog
        sed -i '2 i size 30M' /etc/logrotate.d/php-fpm
        sed -i '2 i rotate 5' /etc/logrotate.d/php-fpm
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/nginx
        sed -i -e 's/rotate 10/rotate 5/g' /etc/logrotate.d/nginx
        sed -i '9 i size 30M' /etc/logrotate.d/fail2ban
        sed -i '9 i rotate 5' /etc/logrotate.d/fail2ban
        sed -i '2 i rotate 5' /etc/logrotate.d/monit
        sed -i -e 's/size 100k/size 30M/g' /etc/logrotate.d/monit
fi
}


addonwatch_install ()
{
if [ ${DIST} = "DEBIAN" ]; then
        chmod +x /opt/ASTPP/misc/addonwatch.py
        apt-get install python3 python3-pip -y
        pip3 install pyinotify
        touch /opt/ASTPP/freeswitch/scripts/addons.lua
        cp ${ASTPP_SOURCE_DIR}/misc/addonwatch.service /etc/systemd/system/addonwatch.service
        chmod +x /etc/systemd/system/addonwatch.service
        systemctl daemon-reload
        systemctl start addonwatch.service
        systemctl enable addonwatch.service
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/freeswitch/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/astpp/

elif [ ${DIST} = "DEBIAN10" ]; then
        chmod +x /opt/ASTPP/misc/addonwatch.py
        apt-get install python3 python3-pip -y
        pip3 install pyinotify
        touch /opt/ASTPP/freeswitch/scripts/addons.lua
        cp ${ASTPP_SOURCE_DIR}/misc/addonwatch.service /etc/systemd/system/addonwatch.service
        chmod +x /etc/systemd/system/addonwatch.service
        systemctl daemon-reload
        systemctl start addonwatch.service
        systemctl enable addonwatch.service
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/freeswitch/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/astpp/
        
elif [ ${DIST} = "CENTOS" ]; then
        
        chmod +x /opt/ASTPP/misc/addonwatch.py
        yum install epel-release -y
        yum install python3 python3-pip -y
        pip3 install pyinotify
        touch /opt/ASTPP/freeswitch/scripts/addons.lua
        cp ${ASTPP_SOURCE_DIR}/misc/addonwatch.service /etc/systemd/system/addonwatch.service
        chmod +x /etc/systemd/system/addonwatch.service
        systemctl daemon-reload
        systemctl start addonwatch.service
        systemctl enable addonwatch.service
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/freeswitch/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /opt/ASTPP/
        sleep 1s
        chmod -Rf 777 /var/www/html/fs/
        sleep 1s
        chmod -Rf 777 /var/www/html/astpp/
        
fi
}


#Remove all downloaded and temp files from server
clean_server ()
{
        cd /usr/src
        rm -rf fail2ban* GNU-AGPLv3.6.txt install.sh mysql80-community-release-el7-1.noarch.rpm
        echo "FS restarting...!"
        systemctl restart freeswitch
        echo "FS restarted...!"
}

#Installation Information Print
start_installation ()
{
        get_linux_distribution
        install_prerequisties
        #license_accept
        get_astpp_source
        get_user_response
        install_mysql
        normalize_mysql
        install_freeswitch
        install_php
        install_astpp
        install_database
        normalize_freeswitch
        normalize_astpp
        #configure_firewall
        install_fail2ban
        install_monit
        logrotate_install
        addonwatch_install
        #clean_server
        #clear
        echo "******************************************************************************************" > /opt/astpp.cred
        echo "******************************************************************************************" >> /opt/astpp.cred
        echo "******************************************************************************************" >> /opt/astpp.cred
        echo "**********                                                                      **********" >> /opt/astpp.cred
        echo "**********           Your ASTPP is installed successfully                       **********" >> /opt/astpp.cred
        echo "                     Browse URL: https://${ASTPP_HOST_DOMAIN_NAME}" 			  >> /opt/astpp.cred
        echo "                     Username: admin" 							  >> /opt/astpp.cred
        echo "                     Password: admin" 							  >> /opt/astpp.cred
        echo "" 											  >> /opt/astpp.cred
        echo "                     MySQL root user password:" 						  >> /opt/astpp.cred
        echo "                     ${MYSQL_ROOT_PASSWORD}"  						  >> /opt/astpp.cred
        echo "" 											  >> /opt/astpp.cred
        echo "                     MySQL astppuser password:" 						  >> /opt/astpp.cred
        echo "                     ${ASTPPUSER_MYSQL_PASSWORD}" 					  >> /opt/astpp.cred
        echo ""  											  >> /opt/astpp.cred
        echo "                     Freeswitch event socket password:" 				  	  >> /opt/astpp.cred
        echo "                     ${FS_EVENT_SOCKET}" 						  	  >> /opt/astpp.cred
	echo ""												  >> /opt/astpp.cred
	echo "If you install 'Multi Tenant IP PBX' addon, please remove below parameters from 'default' sip-profile.">> /opt/astpp.cred
	echo "			   force-register-domain" 						  >> /opt/astpp.cred
	echo "			   force-subscription-domain" 						  >> /opt/astpp.cred
	echo "			   force-register-db-domain" 						  >> /opt/astpp.cred
        echo ""
        echo "**********           IMPORTANT NOTE: Please reboot your server once.            **********"
        echo "**********                                                                      **********" >> /opt/astpp.cred
        echo "******************************************************************************************" >> /opt/astpp.cred
        echo "******************************************************************************************" >> /opt/astpp.cred
        echo "******************************************************************************************" >> /opt/astpp.cred
        cat /opt/astpp.cred
        printf "\n**********    You will get the CREDENTIALS SAVED AT /opt/astpp.cred for future reference.\n\n"
                        read -n 1 -p "Do you want to reboot the server now ? (y/n) "
                if [ "$REPLY"   = "y" ]; then
                        /sbin/reboot now
                        else
                        echo ""
                        echo "Please reboot your server after complete the Installation !"
                fi
}
start_installation
