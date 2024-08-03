# Nextcloud_LinuxMint_UbuntuServer

Funciona en Linux Mint 21.X y Ubuntu 22.04.X (puede ser la version server o la normal)

si no tiene curl instalelo con ```sudo apt install -y curl```

Simplemente copie y pegue esta linea en su terminal
```
curl -s https://raw.githubusercontent.com/chmodmasx/Nextcloud_LinuxMint_UbuntuServer/main/nextcloud_latest.sh >tmp.sh && sudo sh tmp.sh
```

este script instala la versión 28 de Nextcloud desde la página oficial.

- *la base de datos ya viene configurada, no tiene que hacer más*
- *los datos del usuario y base de datos se entregan al finalizar el script en la terminal*
- *memcache y redis serán las cache por defecto en este script, no opte por APCu porque no conozco su hardware, puede optar por cambiarlo de todos modos.*
- Ubicación de instalación: /var/www/html/nextcloud/
- Ubicación de los datos de usuario: /var/nextcloud_data/

![image](https://github.com/chmodmasx/Nextcloud_LinuxMint_UbuntuServer/assets/44514442/0af5740a-0fe5-4593-8d6f-64a888723cd5)

