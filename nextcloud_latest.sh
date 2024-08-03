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
stty -echo
read -p "Ingresa la contraseña para ingresar a Nextcloud: " NC_ADMIN_PASS
stty echo
echo '\n'

#Instala los paquetes necesarios
apt-get update
apt-get -y install apache2 mariadb-server php libapache2-mod-fcgid libapache2-mod-php curl zip unzip wget php-gd php-mysql php-curl php-gmp php-mbstring php-intl php-imagick php-xml php-zip unzip memcached php-memcached redis-server php-redis php-bcmath php-bz2 php-imap php-smbclient php-ldap imagemagick ffmpeg cron

service apache2 start
service mariadb start
service redis-server start

# Descarga y descomprime el archivo zip y mueve la carpeta a /var/www/html/nextcloud
wget https://download.nextcloud.com/server/releases/latest-28.zip
unzip latest-28.zip -d /var/www/html/
rm latest-28.zip

#Obtiene la versión de PHP instalada
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,2,3)

#Configura Apache
a2enmod headers env dir mime proxy_fcgi setenvif php${PHP_VERSION} ssl

service apache2 reload

# Creamos el archivo de configuración de apache para Nextcloud, incluyendo las redirecciones
echo "<VirtualHost *:80>
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

    ErrorLog ${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog ${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
" | tee /etc/apache2/sites-available/nextcloud.conf


# Habilitamos el archivo de configuración
a2ensite nextcloud.conf
a2dissite 000-default.conf
a2enmod rewrite

# Configura la base de datos MariaDB

#DB_USER="runicblade"
DB_USER="user_$(openssl rand -hex 4)"
DB_PASS=$(openssl rand -base64 12)
#DB_NAME="nextcloud"
DB_NAME="db_$(openssl rand -hex 4)"
DB_HOST="localhost"

mysql -u root -S /var/run/mysqld/mysqld.sock -e "CREATE USER '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';"
mysql -u root -S /var/run/mysqld/mysqld.sock -e "CREATE DATABASE $DB_USER;"
mysql -u root -S /var/run/mysqld/mysqld.sock -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';"
mysql -u root -S /var/run/mysqld/mysqld.sock -e "FLUSH PRIVILEGES;"


cat <<EOF | tee /var/www/html/nextcloud/config/autoconfig.php
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
  'maintenance_window_start' => 1,
  'enable_previews' => true,
  'enabledPreviewProviders' =>
  array (
    0 => 'OC\\Preview\\Movie',
    1 => 'OC\\Preview\\PNG',
    2 => 'OC\\Preview\\JPEG',
    3 => 'OC\\Preview\\GIF',
    4 => 'OC\\Preview\\BMP',
    5 => 'OC\\Preview\\XBitmap',
    6 => 'OC\\Preview\\MP3',
    7 => 'OC\\Preview\\MP4',
    8 => 'OC\\Preview\\TXT',
    9 => 'OC\\Preview\\MarkDown',
    10 => 'OC\\Preview\\PDF',
    11 => 'OC\\Preview\\HEIC',
    12 => 'OC\\Preview\\HEIF',
    13 => 'OC\\Preview\\TIFF',
    14 => 'OC\\Preview\\WEBP',
    15 => 'OC\\Preview\\Image',
  ),
  'logfile' => '/var/log/nextcloud.log',
);
EOF

mkdir /var/nextcloud_data
chown www-data:www-data /var/nextcloud_data
# Permisos a datos de usuario
chmod 755 /var/nextcloud_data

# Damos permisos a la carpeta HTML para el usuario www-data
chown -R www-data:www-data /var/www/html/nextcloud/
chmod -R ug+rw /var/www/html/nextcloud/
chmod -R 770 /var/www/html/nextcloud/config

su -s /bin/bash -c "php /var/www/html/nextcloud/occ maintenance:install --database=mysql --database-name=$DB_NAME --database-user=$DB_USER --database-pass=$DB_PASS --admin-user=$NC_ADMIN_USER --admin-pass=$NC_ADMIN_PASS --data-dir=/var/nextcloud_data" www-data

##### Configuraciones de nextcloud config.php y www.conf #####

# Habilitamos el modulo gmp de php
sed -i 's/;extension=gmp/extension=gmp/' /etc/php/${PHP_VERSION}/apache2/php.ini
# Se agrega el dominio a los host confiables de nextcloud
sed -i "s/'localhost',/'localhost',\n  1 => '$domain',/" /var/www/html/nextcloud/config/config.php
# Añadido para cloudflare (proxie inverso)
sed -i "/);/i \  'overwriteprotocol' => 'https'," /var/www/html/nextcloud/config/config.php
# overwrite.cli.url
sed -i "s/'overwrite.cli.url' => 'http:\/\/localhost',/'overwrite.cli.url' => 'https:\/\/$domain',/" /var/www/html/nextcloud/config/config.php
# htaccess.RewriteBase
sed -i "/^);/i \ \ 'htaccess.RewriteBase' => '/'," /var/www/html/nextcloud/config/config.php
# Región telefónica
sed -i "/);/i \  'default_phone_region' => '$phone_region'," /var/www/html/nextcloud/config/config.php
sed -i "/);/i \  'maintenance_window_start' => 1," /var/www/html/nextcloud/config/config.php

# Configura la tarea cron para Nextcloud como usuario www-data
su -s /bin/bash -c "crontab -l | { cat; echo '*/5 * * * * php -f /var/www/html/nextcloud/cron.php'; } | crontab -u www-data -" www-data


# Añade la configuración de fondo (background) a config.php
su -s /bin/bash -c "php /var/www/html/nextcloud/occ config:system:set background --value=cron" www-data


# Configuración de Memcaches
sed -i "/);/i \  'memcache.local' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php
sed -i "/);/i \  'memcache.distributed' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php
# redis
sed -i "/^);/i \  'redis' => [\n      'host' => 'localhost',\n      'port' => 6379,\n  ],\n  'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis'," /var/www/html/nextcloud/config/config.php

# Añadimos el usuario www-data al grupo redis
usermod -a -G redis www-data

# Actualizamos el archivo .htaccess
su - www-data -s /bin/bash -c 'php /var/www/html/nextcloud/occ maintenance:update:htaccess'
su - www-data -s /bin/bash -c 'php /var/www/html/nextcloud/occ db:add-missing-indices'

# Cambiamos los valores de limitación de tamaño de archivos de php y user.ini

echo "upload_max_filesize = 8192M" >> /var/www/html/nextcloud/.user.ini
echo "post_max_size = 8192M" >> /var/www/html/nextcloud/.user.ini
sed -i 's/memory_limit = 128M/memory_limit = 1024M/g' /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 8192M/g' /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 8192M/g' /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/output_buffering =.*/output_buffering = Off/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 3600/g' /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i 's/max_input_time = 60/max_input_time = 3600/g' /etc/php/${PHP_VERSION}/apache2/php.ini

# Valores de configuración de OPcache para Nextcloud
opcache_settings="zend_extension=opcache
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=1024
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=10000
opcache.revalidate_freq=0
"

echo "$opcache_settings" |  tee -a "/etc/php/"${PHP_VERSION}"/apache2/php.ini" >/dev/null

# Redis
redis_settings="redis.session.locking_enabled=1
redis.session.lock_retries=-1
redis.session.lock_wait_time=10000
"

echo "$redis_settings" |  tee -a "/etc/php/"${PHP_VERSION}"/apache2/php.ini" >/dev/null

su - www-data -s /bin/bash -c 'php /var/www/html/nextcloud/occ db:add-missing-indices'

service apache2 reload

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
echo "También puede acceder en local abriendo http://localhost/core/apps/recommended"
