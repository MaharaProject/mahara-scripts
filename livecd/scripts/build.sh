#!/bin/sh

# Copy the folder scripts to chroot /tmp dir
# and Run /tmp/scripst/build.sh

# Requirement
# - iso file for Desktop Ubuntu 14.04.5 in ./iso/ubuntu-14.04.5-basicdesktop-amd64.iso

# This script will
# - install required packages for mahara
# - setup mahara code, sample mahara database and dataroot

# Install required packages

#add-apt-repository universe
#apt-get update

#apt-get -y install tasksel
# Remove not required packages
#apt-get -y remove \
#    tasksel\
#    xterm xdg-utils xcursor-themes vino usb-creator-gtk unity-webapps-common ubuntu-docs\
#    ttf-punjabi-fonts ttf-indic-fonts-core transmission-gtk totem-mozilla totem thunderbird-gnome-support thunderbird \
#    telepathy-idle sni-qt simple-scan shotwell rhythmbox-plugin-magnatune rhythmbox remmina qt-at-spi\
#    python3-aptdaemon.pkcompat pulseaudio-module-x11 pulseaudio-module-bluetooth\
#    nautilus-share libwmf0.2-7-gtk\
#    libreoffice-writer libreoffice-style-human libreoffice-presentation-minimizer libreoffice-pdfimport\
#    libreoffice-ogltrans libreoffice-math libreoffice-impress libreoffice-gnome libreoffice-calc \
#    gnome-terminal gnome-sudoku gnome-mahjongg gnome-disk-utility gnome-bluetooth \
#    empathy example-content deja-dup cheese brasero branding-ubuntu
#apt-get autoclean
#apt-get autoremove

# Install Apache2, PostgreSQL, Php5
#apt-get -y install \
#    sudo \
#    sendmail \
#    memcached \
#    cron \
#    apache2 \
#    postgresql postgresql-contrib \
#    php5 \
#    php5-cli\
#    curl\
#    libapache2-mod-php5 \
#    php5-pgsql \
#    php5-mysql \
#    php5-gd \
#    php5-curl \
#    php5-json \
#    php5-ldap \
#    php5-xmlrpc \
#    php5-mcrypt \
#    php5-memcache\
#    php5-gmp\
#    php5-sqlite

#dpkg -i /tmp/scripts/packages/elasticsearch-1.5.2.deb

#apt-get -y install git

# Setup mahara site
#	Mahara code
# Option 1: use a mahara release from https://launchpad.net/mahara
#tar xfz tmp/scripts/mahara/code/mahara-16.10rc1.tar.gz --directory /var/www/html
#mv /var/www/html/mahara-16.10rc1/htdocs/* /var/www/html
#chown -R www-data.www-data /var/www/html
# Option 2: use git to pull current mahara code from https://git.mahara.org/mahara/mahara.git
# everytime booting, use the snapshot code if internet is not available
rm -f /var/www/html/index.html
chown -R www-data /var/www
sudo -H -u www-data git clone https://git.mahara.org/mahara/mahara.git /var/www/html
apt-get -y install npm nodejs-legacy
sudo npm install -g gulp
cd /var/www/html
sudo -H -u www-data make clean-css
sudo -H -u www-data make css
cd /

# Apache configuration
sed -ri 's/\/var\/www\/html$/\/var\/www\/html\/htdocs/g' /etc/apache2/sites-available/000-default.conf
# PHP configuration
sed -ri 's/^post_max_size = [0-9]+M$/post_max_size = 50M/g' /etc/php5/apache2/php.ini

#	Mahara dataroot
mkdir -p /var/lib/sitedata
tar xfz /tmp/scripts/mahara/dataroot/*.tar.gz --directory /var/lib/sitedata
chown -R www-data.www-data /var/lib/sitedata
#	Mahara database
#echo -e 'LANG=en_NZ.UTF-8\nLC_ALL=en_NZ.UTF-8\nLANGUAGE=en_NZ:en' > /etc/default/locale
#sudo locale-gen en_NZ en_NZ.UTF-8
#dpkg-reconfigure locales
# Update listen_addresses and port settings for Postgres
sed -ri 's/^\#listen_addresses.*/listen_addresses = "localhost"/g' /etc/postgresql/9.3/main/postgresql.conf
sed -ri 's/^port\s*=\s*[0-9]+/port = 5434/g' /etc/postgresql/9.3/main/postgresql.conf

service postgresql start
service postgresql status
sudo -u postgres psql -c "CREATE USER maharauser WITH NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD 'mahara'"
sudo -u postgres psql -c "CREATE DATABASE maharadb OWNER maharauser ENCODING 'utf8' TEMPLATE template0"
sudo -u postgres pg_restore --no-owner --role=maharauser -d maharadb /tmp/scripts/mahara/database/*.pg
service postgresql stop

#	Mahara config update
cp /tmp/scripts/mahara/config.php /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dbtype\s*=\s*.*;/\$cfg->dbtype = "postgres";/g' /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dbhost\s*=\s*.*;/\$cfg->dbhost = "localhost";/g' /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dbport\s*=\s*.*;/\$cfg->dbport = 5434;/g' /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dbname\s*=\s*.*;/\$cfg->dbname = "maharadb";/g' /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dbuser\s*=\s*.*;/\$cfg->dbuser = "maharauser";/g' /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dbpass\s*=\s*.*;/\$cfg->dbpass = "mahara";/g' /var/www/html/htdocs/config.php
sed -ri 's/^\$cfg->dataroot\s*=\s*.*;/\$cfg->dataroot = "\/var\/lib\/sitedata";/g' /var/www/html/htdocs/config.php
#	Mahara cron job
echo -e "*  *    * * *   www-data  php /var/www/html/lib/cron.php >> /var/lib/sitedata/cron.log 2>&1\n" > /etc/cron.d/mahara

# Add a system user: ubuntu
adduser ubuntu
adduser ubuntu sudo

# Password less for sudo group
sed -ri 's/^\%sudo	ALL=(ALL:ALL) ALL$/\%sudo      ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers

# Auto login as the system user: mahara
#if [ -f /etc/lightdm/lightdm.conf ]; then
#  sed -ri 's/^autologin-user=.*/autologin-user=mahara/g' /etc/lightdm/lightdm.conf
#else
#  cp /tmp/scripts/autologin/lightdm.conf /etc/lightdm/lightdm.conf
#fi

# Auto open Mahara site in firefox
if [ ! -d /home/ubuntu/.config/autostart ]; then
  mkdir -p /home/ubuntu/.config/autostart
fi
cp /tmp/scripts/mahara/autostart/* /home/ubuntu/.config/autostart
chmod +x /home/ubuntu/.config/autostart/*.sh
chown -R ubuntu /home/ubuntu/.config

