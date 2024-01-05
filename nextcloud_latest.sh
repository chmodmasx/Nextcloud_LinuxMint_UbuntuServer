#!/bin/bash

echo "   ____       _                         _                          ";
echo "  / __ \  ___| |__  _ __ ___   ___   __| |_ __ ___   __ _ _____  __";
echo " / / _\` |/ __| '_ \| '_ \` _ \ / _ \ / _\` | '_ \` _ \ / _\` / __\ \/ /";
echo "| | (_| | (__| | | | | | | | | (_) | (_| | | | | | | (_| \__ \>  < ";
echo " \ \__,_|\___|_| |_|_| |_| |_|\___/ \__,_|_| |_| |_|\__,_|___/_/\_\ ";
echo "  \____/                                                           ";
echo "En Dios confiamos | In God we trust"
echo "\n"

# Ingresa tu dominio
read -p 'Inserte su dominio, por ejemplo espadarunica.com: ' domain
echo '\n'
# Pide la región telefonica
echo "\e[4mRegión telefónica\e[0m"
echo "puede visitar https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements para más información"
echo '\n'
read -p 'Ingrese su región telefónica (AR, MX, US): ' phone_region
echo '\n'
# Pide los datos para la cuenta de administrador
read -p "Ingresa el nombre de usuario para ingresar a Nextcloud: " NC_ADMIN_USER
echo '\n'
read -p "Ingresa la contraseña para ingresar a Nextcloud: " NC_ADMIN_PASS
echo '\n'

#Instala los paquetes necesarios
apt-get update
apt-get -y install apache2 mariadb-server libapache2-mod-fcgid php-fpm php-gd php-mysql php-curl php-gmp php-mbstring php-intl php-imagick php-xml php-zip unzip memcached php-memcached redis-server php-redis php-bcmath php-bz2 php-imap php-smbclient php-ldap imagemagick ffmpeg

# Descarga y descomprime el archivo zip y mueve la carpeta a /var/www/html/nextcloud
wget https://download.nextcloud.com/server/releases/latest.zip
sudo unzip latest.zip -d /var/www/html/

#Obtiene la versión de PHP instalada
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,2,3)

#Configura Apache
a2enmod rewrite
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
a2enmod proxy_fcgi setenvif
a2enconf php${PHP_VERSION}-fpm
a2enmod ssl
a2ensite default-ssl

systemctl restart php${PHP_VERSION}-fpm.service
systemctl restart apache2.service




# Creamos el archivo de configuración de apache para Nextcloud, incluyendo las redirecciones
sudo echo "<VirtualHost *:80>
  DocumentRoot /var/www/html/nextcloud/
  ServerName $domain

  Redirect 301 /.well-known/carddav https://$domain/remote.php/dav
  Redirect 301 /.well-known/caldav  https://$domain/remote.php/dav
  Redirect 301 /.well-known/webdav  https://$domain/remote.php/dav

  <Directory /var/www/html/nextcloud/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews

    <IfModule mod_dav.c>
      Dav off
    </IfModule>

  </Directory>
</VirtualHost>" | sudo tee /etc/apache2/sites-available/nextcloud.conf


# Habilitamos el archivo de configuración
sudo a2ensite nextcloud.conf

# Configura la base de datos MariaDB

#DB_USER="runicblade"
DB_USER="user_$(openssl rand -hex 4)"
DB_PASS=$(openssl rand -base64 12)
#DB_NAME="nextcloud"
DB_NAME="db_$(openssl rand -hex 4)"
DB_HOST="localhost"

sudo mysql -e "CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "CREATE DATABASE $DB_USER;"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';"
sudo mysql -e "FLUSH PRIVILEGES;"

cat <<EOF | sudo tee /var/www/html/nextcloud/config/autoconfig.php
<?php
\$AUTOCONFIG = array (
  'dbtype' => 'mysql',
  'dbname' => '$DB_NAME',
  'dbuser' => '$DB_USER',
  'dbpass' => '$DB_PASS',
  'dbhost' => '$DB_HOST',
  'dbtableprefix' => 'oc_',
  'adminlogin' => '$NC_ADMIN_USER',
  'adminpass' => '$NC_ADMIN_PASS',
  'directory' => '/var/www/html/nextcloud/data',
  'overwriteprotocol' => 'https',
  'overwrite.cli.url' => 'https://$domain',
  'overwritehost' => '$domain',
);
EOF

mkdir /var/nextcloud_data
chown www-data:www-data /var/nextcloud_data
# Permisos a datos de usuario
chmod 755 /var/nextcloud_data

# Limpia los archivos innecesarios
rm latest.zip

# Damos permisos a la carpeta HTML para el usuario www-data
sudo chown -R www-data:www-data /var/www/html/nextcloud/
sudo chmod -R ug+rw /var/www/html/nextcloud/
sudo chmod -R 770 /var/www/html/nextcloud/config

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:install --database "mysql" --database-name "$DB_NAME" --database-user "$DB_USER" --database-pass "$DB_PASS" --admin-user "$NC_ADMIN_USER" --admin-pass "$NC_ADMIN_PASS" --data-dir /var/nextcloud_data

##### Configuraciones de nextcloud config.php y www.conf #####

# Descomentamos las variables de www.conf
sudo sed -i 's/;\(env\[HOSTNAME\] = \$HOSTNAME\)/\1/' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sudo sed -i 's/;\(env\[PATH\] = \/usr\/local\/bin:\/usr\/bin:\/bin\)/\1/' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sudo sed -i 's/;\(env\[TMP\] = \/tmp\)/\1/' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sudo sed -i 's/;\(env\[TMPDIR\] = \/tmp\)/\1/' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
sudo sed -i 's/;\(env\[TEMP\] = \/tmp\)/\1/' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

# Habilitamos el modulo gmp de php
sed -i 's/;extension=gmp/extension=gmp/' /etc/php/${PHP_VERSION}/fpm/php.ini
# Se agrega el dominio a los host confiables de nextcloud
sudo sed -i "s/'localhost',/'localhost',\n  1 => '$domain',/" /var/www/html/nextcloud/config/config.php
# Añadido para cloudflare (proxie inverso)
sudo sed -i "/);/i \  'overwriteprotocol' => 'https'," /var/www/html/nextcloud/config/config.php
# overwrite.cli.url
sudo sed -i "s/'overwrite.cli.url' => 'http:\/\/localhost',/'overwrite.cli.url' => 'https:\/\/$domain',/" /var/www/html/nextcloud/config/config.php
# htaccess.RewriteBase
sudo sed -i "/^);/i \ \ 'htaccess.RewriteBase' => '/'," /var/www/html/nextcloud/config/config.php
# Región telefónica
sudo sed -i "/);/i \  'default_phone_region' => '$phone_region'," /var/www/html/nextcloud/config/config.php

# Configura la tarea cron para Nextcloud como usuario www-data
sudo -u www-data crontab -l | { cat; echo "*/5 * * * * /usr/bin/php$PHP_VERSION /var/www/html/nextcloud/cron.php"; } | sudo -u www-data crontab -

# Añade la configuración de fondo (background) a config.php
sudo -u www-data php /var/www/html/nextcloud/occ config:system:set background --value=cron


# Configuración de Memcaches
sudo sed -i "/);/i \  'memcache.local' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php
sudo sed -i "/);/i \  'memcache.distributed' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php
# redis
sudo sed -i "/^);/i \  'redis' => [\n      'host' => 'localhost',\n      'port' => 6379,\n  ],\n  'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php

# Añadimos el usuario www-data al grupo redis
sudo usermod -a -G redis www-data

# Actualizamos el archivo .htaccess
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:update:htaccess

# Cambiamos los valores de limitación de tamaño de archivos de php-fpm y user.ini

echo "upload_max_filesize = 8192M" >> /var/www/html/nextcloud/.user.ini
echo "post_max_size = 8192M" >> /var/www/html/nextcloud/.user.ini
sed -i 's/memory_limit = 128M/memory_limit = 1024M/g' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 8192M/g' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 8192M/g' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i "s/output_buffering =.*/output_buffering = Off/g" /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 3600/g' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/max_input_time = 60/max_input_time = 3600/g' /etc/php/${PHP_VERSION}/fpm/php.ini
systemctl restart php${PHP_VERSION}-fpm.service

# Valores de configuración de OPcache para Nextcloud
opcache_settings="zend_extension=opcache
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=1024
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=10000
opcache.revalidate_freq=0
"

echo "$opcache_settings" | sudo tee -a "/etc/php/"${PHP_VERSION}"/fpm/php.ini" >/dev/null

# Redis
redis_settings="redis.session.locking_enabled=1
redis.session.lock_retries=-1
redis.session.lock_wait_time=10000
"

echo "$redis_settings" | sudo tee -a "/etc/php/"${PHP_VERSION}"/fpm/php.ini" >/dev/null


sudo systemctl restart apache2
sudo systemctl restart php${PHP_VERSION}-fpm.service

echo '\n'

echo "   ____       _                         _                          ";
echo "  / __ \  ___| |__  _ __ ___   ___   __| |_ __ ___   __ _ _____  __";
echo " / / _\` |/ __| '_ \| '_ \` _ \ / _ \ / _\` | '_ \` _ \ / _\` / __\ \/ /";
echo "| | (_| | (__| | | | | | | | | (_) | (_| | | | | | | (_| \__ \>  < ";
echo " \ \__,_|\___|_| |_|_| |_| |_|\___/ \__,_|_| |_| |_|\__,_|___/_/\_\ ";
echo "  \____/                                                           ";
echo "En Dios confiamos | In God we trust"
echo "\n"

# Muestra los datos de la configuración
echo "\e[4mDatos de la base de datos Nextcloud:\e[0m"
echo "URL: $domain"
echo "Usuario de la base de datos: ${DB_USER}"
echo "Contraseña de la base de datos: ${DB_PASS}"
echo "Nombre de la base de datos: ${DB_NAME}"
echo "Host de la base de datos: ${DB_HOST}"
echo '\n'
echo "\e[4mDatos del usuario Nextcloud:\e[0m"
echo "Usuario de administrador de Nextcloud: ${NC_ADMIN_USER}"
echo "Contraseña de administrador de Nextcloud: ${NC_ADMIN_PASS}"
echo '\n'
echo "Ingrese a https://$domain/core/apps/recommended"
