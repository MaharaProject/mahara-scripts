#!/bin/sh

# This script create a Ubuntu LiveCD from scratch
# Run this script as a normal user
# Output: ../iso/ubuntu-14.04-basic-amd64.iso

# Install required packages syslinux, squashfs-tools and genisoimage
# need sudo privilege

sudo apt-get -y install syslinux squashfs-tools genisoimage

# Create a disk image folder
DIR="$( cd "$( dirname $( dirname "${BASH_SOURCE[0]}" ) )" && pwd )"
mkdir -p $DIR/work/image

# Make the ChRoot Env
sudo apt-get -y install debootstrap
mkdir -p $DIR/work/chroot
cd $DIR/work
sudo debootstrap --arch=amd64 trusty chroot http://ubuntu.catalyst.net.nz/ubuntu

sudo mount --bind /dev chroot/dev
sudo cp /etc/hosts chroot/etc/hosts
sudo cp /etc/resolv.conf chroot/etc/resolv.conf
sudo cp /etc/apt/sources.list chroot/etc/apt/sources.list

sudo chroot chroot

#mount none -t proc /proc
#mount none -t sysfs /sys
#mount none -t devpts /dev/pts
#export HOME=/root
#export LC_ALL=C

#apt-get update
#apt-get install --yes dbus
#dbus-uuidgen > /var/lib/dbus/machine-id
#dpkg-divert --local --rename --add /sbin/initctl

#ln -s /bin/true /sbin/initctl

#apt-get --yes upgrade

#apt-get install --yes ubuntu-standard casper lupin-casper
#apt-get install --yes discover laptop-detect os-prober
#apt-get install --yes linux-generic

#apt-get install --yes ubuntu-desktop

# Cleanup the ChRoot Environment
#rm /var/lib/dbus/machine-id
#rm /sbin/initctl
#dpkg-divert --rename --remove /sbin/initctl
#apt-get clean

#rm -rf /tmp/*

#rm /etc/resolv.conf

#umount -lf /proc
#umount -lf /sys
#umount -lf /dev/pts
exit
sudo umount /path/to/chroot/dev

#Create the Cd Image Directory and Populate it
mkdir -p image/{casper,isolinux,install}
sudo cp chroot/boot/vmlinuz-*-generic image/casper/vmlinuz
sudo cp chroot/boot/initrd.img-*-generic image/casper/initrd.lz
sudo cp /usr/lib/syslinux/isolinux.bin image/isolinux/
sudo cp /boot/memtest86+.bin image/install/memtest

# Boot-loader Configuration

# Create manifest

# Compress the chroot

# Create diskdefines

# Calculate MD5

# Create ISO Image for a LiveCD




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
apt-get -y install \
    sudo \
    sendmail \
    memcached \
    cron \
    apache2 \
    postgresql postgresql-contrib \
    php5 \
    php5-cli\
    curl\
    libapache2-mod-php5 \
    php5-pgsql \
    php5-mysql \
    php5-gd \
    php5-curl \
    php5-json \
    php5-ldap \
    php5-xmlrpc \
    php5-mcrypt \
    php5-memcache\
    php5-gmp\
    php5-sqlite

dpkg -i /tmp/scripts/packages/elasticsearch-1.5.2.deb

# Setup mahara site
#	Mahara code
rm -f /var/www/html/index.html
cp -R /tmp/scripts/mahara/code/htdocs/* /var/www/html
chown -R www-data.www-data /var/www/html
#	Mahara dataroot
mkdir -p /var/lib/sitedata/
cp -R /tmp/scripts/mahara/dataroot/* /var/lib/sitedata/
chown -R www-data.www-data /var/lib/sitedata
#	Mahara database
echo -e 'LANG=en_NZ.UTF-8\nLC_ALL=en_NZ.UTF-8\nLANGUAGE=en_NZ:en' > /etc/default/locale
sudo locale-gen en_NZ en_NZ.UTF-8
dpkg-reconfigure locales
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
sed -ri 's/^\$cfg->dbtype\s*=\s*.*;/\$cfg->dbtype = "postgres";/g' /var/www/html/config.php
sed -ri 's/^\$cfg->dbhost\s*=\s*.*;/\$cfg->dbhost = "localhost";/g' /var/www/html/config.php
sed -ri 's/^\$cfg->dbport\s*=\s*.*;/\$cfg->dbport = 5434;/g' /var/www/html/config.php
sed -ri 's/^\$cfg->dbname\s*=\s*.*;/\$cfg->dbname = "maharadb";/g' /var/www/html/config.php
sed -ri 's/^\$cfg->dbuser\s*=\s*.*;/\$cfg->dbuser = "maharauser";/g' /var/www/html/config.php
sed -ri 's/^\$cfg->dbpass\s*=\s*.*;/\$cfg->dbpass = "mahara";/g' /var/www/html/config.php
sed -ri 's/^\$cfg->dataroot\s*=\s*.*;/\$cfg->dataroot = "\/var\/lib\/sitedata";/g' /var/www/html/config.php
#	Mahara cron job
echo -e "*  *    * * *   www-data  php /var/www/html/lib/cron.php >> /var/lib/sitedata/cron.log 2>&1\n" > /etc/cron.d/mahara

# Add a system user: mahara
adduser mahara
adduser mahara sudo

# Auto login as the system user: mahara
#if [ -f /etc/lightdm/lightdm.conf ]; then
#  sed -ri 's/^autologin-user=.*/autologin-user=mahara/g' /etc/lightdm/lightdm.conf
#else
#  echo -e "autologin-user=mahara\n" > /etc/lightdm/lightdm.conf
#fi

# Auto open Mahara site in firefox
#if [ ! -d /home/mahara/.config/autostart ]; then
#  mkdir -p /home/mahara/.config/autostart
#fi
#cp /tmp/scripts/autostart/* /home/mahara/.config/autostart
#chown -R mahara.mahara /home/mahara/.config

