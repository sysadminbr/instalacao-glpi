# Instalacao do GLPI  


## 1. Pré-Requisitos  

✅ Servidor Ubuntu 22.04LTS Instalado  
✅ Acesso a internet para download e instalação de pacotes  
✅ Acesso de root ao servidor  

  
## 2. Instalação
2.1. Atualizar o Sistema Operacional  
```
sudo apt update  
sudo apt dist-upgrade -y
```

2.2. Configurar o timezone corretamente  
```
sudo dpkg-reconfigure tzdata
```

2.3. Reiniciar (opcional)
```
sudo reboot
```

2.4. Instalar Nginx, PHP e MySQL
```
sudo apt install -y \
	nginx \
	mariadb-server \
	mariadb-client \
	php-fpm \
	php-dom \
	php-fileinfo   \
	php-json \
	php-simplexml \
	php-xmlreader \
	php-xmlwriter \
	php-curl \
	php-gd \
	php-intl \
	php-mysqli   \
	php-bz2  \
	php-zip \
	php-exif \
	php-ldap  \
	php-opcache \
	php-mbstring
```  


2.5. Criar banco de dados do glpi  
```
sudo mysql -e "CREATE DATABASE glpi"
sudo mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost' IDENTIFIED BY '1cd73cddc8dad1fef981391f'"
sudo mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'"
sudo mysql -e "FLUSH PRIVILEGES"
```  

2.6. Carregar timezones no MySQL  
```
mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root mysql
```



2.8. Habilita session.cookie_httponly  
```
sudo sed -i 's/^session.cookie_httponly =/session.cookie_httponly = on/' /etc/php/8.1/fpm/php.ini
sudo sed -i 's/^;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/8.1/fpm/php.ini
```
	

2.9. Criar o arquivo de configuração do servidor web (nginx) com o seguinte comando:  
```
cat << "EOF" > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 768;
}
http {
        sendfile on;
        tcp_nopush on;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

        server {
            listen 80;
            server_name _;
            root /var/www/glpi/public;
            index index.php;
            location / {
                try_files $uri /index.php$is_args$args;
            }
            location ~ ^/index\.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:/run/php/php8.1-fpm.sock;
                fastcgi_index index.php;
                include /etc/nginx/fastcgi.conf;
            }
        }
}
EOF
```


2.12. Reinicia os serviços necessários  
```
sudo systemctl restart nginx php8.1-fpm mysql
```


2.13. Download do glpi  
```
wget https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz
```

2.14. Descompactar a pasta do GLPI  
```
tar -zxf glpi-*
```

2.15. Mover a pasta do GLPI para a pasta htdocs  
```
sudo mv glpi /var/www/glpi
```


2.16. Configura a permissão na pasta www/glpi  
```
sudo chown -R www-data:www-data /var/www/glpi/
```



2.17. Finalizar setup do glpi pela linha de comando  
```
sudo php /var/www/glpi/bin/console db:install \
	--default-language=pt_BR \
	--db-host=localhost \
	--db-port=3306 \
	--db-name=glpi \
	--db-user=glpi \
	--db-password=1cd73cddc8dad1fef981391f \
	--no-interaction
```



## 3. Ajustes de Segurança  
3.1. Remover o arquivo de instalação  
```
sudo rm /var/www/glpi/install/install.php
```


3.2. Mover pastas do GLPI de forma segura   
```
sudo mv /var/www/glpi/files /var/lib/glpi
sudo mv /var/www/glpi/config /etc/glpi
sudo mkdir /var/log/glpi
sudo chown -R www-data:www-data /var/log/glpi
```


3.3. Criar o arquivo /var/www/glpi/inc/downstream.php com o seguinte conteúdo:  
```
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
   require_once GLPI_CONFIG_DIR . '/local_define.php';
}
```

3.4. Criar o Arquivo /etc/glpi/local_define.php com o seguinte conteúdo:  
```
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_LOG_DIR', '/var/log/glpi');
```



### 4. Primeiros Passos   
4.1. Acessar o GLPI via web browser   
4.2. Criar um novo usuário com perfil super-admin  
4.3. Remover os usuários glpi, normal, post-only, tech.  
4.3.1. Enviar os usuários para a lixeira  
4.3.2. Remover permanentemente  
4.3.4. Configurar a url de acesso ao sistema em: Configurar -> Geral -> Configuração Geral -> URL da aplicação.  

### 5. Referências
https://faq.teclib.com/03_knowledgebase/procedures/install_glpi/

	


