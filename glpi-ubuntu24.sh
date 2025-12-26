#!/bin/bash
#---------------------------------------
# Script to install GLPI
# Citrait - excelencia em TI
# Author: luciano@citrait.com.br
#---------------------------------------

# only runs on ubuntu 24.04
lsb_release -a | grep Release | grep 24.04 >/dev/null
if [ "$?" != "0" ]; then
    echo "This script only runs on ubuntu 24.04 (noble)"
    exit 0
fi

# root detection
if [ $(id -u) -ne 0 ]; then
    echo "This script MUST be executed as root."
	exit 0
fi

# less verbosity during package install
export DEBIAN_FRONTEND=noninteractive

# make sure we start patched
apt update && apt upgrade

# pre-reqs
apt install -y apache2 \
    php \
	php-{apcu,cli,common,curl,gd,imap,ldap,mysql,xmlrpc,xml,mbstring,bcmath,intl,zip,redis,bz2} \
	libapache2-mod-php \
	php-soap \
	php-cas \
	mariadb-server

# generate mysql_root_password
export MYSQL_ROOT_PASSWORD=$(openssl rand -base64 16 | tr -d [^:alpha:])
echo $MYSQL_ROOT_PASSWORD > $HOME/mysql_root_password

# mysql setup
mysql_secure_installation << EOF 

n
Y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
Y
Y
Y
Y
EOF

# load timezone into mysql
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql mysql

# generate glpi password for mysql
export GLPI_DB_PASSWORD=$(openssl rand -base64 16 | tr -d [^:alpha:])
echo $GLPI_DB_PASSWORD > $HOME/glpi_db_password

# setup glpi database
mysql -e "CREATE DATABASE glpi;"
mysql -e "CREATE USER 'glpi'@'localhost' IDENTIFIED BY '$GLPI_DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost';"
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'"
mysql -e "FLUSH PRIVILEGES;"

# installing the glpi web app
cd /var/www/html
wget https://github.com/glpi-project/glpi/releases/download/10.0.19/glpi-10.0.19.tgz
tar -xvzf glpi-10.0.19.tgz

# downstream
cat << 'EOF' > /var/www/html/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

# move the downstream reference folders
mv /var/www/html/glpi/config /etc/glpi
mv /var/www/html/glpi/files /var/lib/glpi
mv /var/lib/glpi/_log /var/log/glpi

# configure the includes
cat << 'EOF' > /etc/glpi/local_define.php
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_DOC_DIR', GLPI_VAR_DIR);
define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCAL_I18N_DIR', GLPI_VAR_DIR . '/_locales');
define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
define('GLPI_INVENTORY_DIR', GLPI_VAR_DIR . '/_inventories');
define('GLPI_THEMES_DIR', GLPI_VAR_DIR . '/_themes');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

# glpi initial setup
sudo php /var/www/html/glpi/bin/console db:install \
	--default-language=pt_BR \
	--db-host=localhost \
	--db-port=3306 \
	--db-name=glpi \
	--db-user=glpi \
	--db-password="$GLPI_DB_PASSWORD" \
	--no-interaction

# fix permissions on web dir
chown root:root /var/www/html/glpi/ -R
chown www-data:www-data /etc/glpi -R
chown www-data:www-data /var/lib/glpi -R
chown www-data:www-data /var/log/glpi -R
chown www-data:www-data /var/www/html/glpi/marketplace -Rf
find /var/www/html/glpi/ -type f -exec chmod 0644 {} \;
find /var/www/html/glpi/ -type d -exec chmod 0755 {} \;
find /etc/glpi -type f -exec chmod 0644 {} \;
find /etc/glpi -type d -exec chmod 0755 {} \;
find /var/lib/glpi -type f -exec chmod 0644 {} \;
find /var/lib/glpi -type d -exec chmod 0755 {} \;
find /var/log/glpi -type f -exec chmod 0644 {} \;
find /var/log/glpi -type d -exec chmod 0755 {} \;

# creating the vhost on apache2
cat << 'EOF' > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerName yourglpi.yourdomain.com
    DocumentRoot /var/www/html/glpi/public
    <Directory /var/www/html/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF

# php parameters
sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php/8.*/apache2/php.ini
sed -i 's/^post_max_size = 8M/post_max_size = 128M/' /etc/php/8.*/apache2/php.ini
sed -i 's/^max_execution_time = 30/max_execution_time = 60/' /etc/php/8.*/apache2/php.ini
sed -i 's/^;max_input_vars = 1000/max_input_vars = 5000/' /etc/php/8.*/apache2/php.ini
sed -i 's/^memory_limit = 128M/memory_limit = 256M/' /etc/php/8.*/apache2/php.ini
sed -i 's/^session.cookie_httponly =/session.cookie_httponly = On/' /etc/php/8.*/apache2/php.ini
sed -i 's/^;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/8.*/apache2/php.ini

# enable the vhost
a2dissite 000-default.conf
a2enmod rewrite
a2ensite glpi.conf
systemctl restart apache2

# finished.
echo "Finished GLPI SETUP"
echo "Generated passwords are saved into homedir $HOME"


