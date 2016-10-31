FROM ubuntu:12.04.5
MAINTAINER Son Nguyen <son.nguyen@catalyst.net.nz>
# Ubuntu 12.04, Apache 2.2, Php 5.3, MySQL 5.5

VOLUME ["/var/www/html"]
VOLUME ["/var/lib/sitedata"]

RUN apt-get update && \
    apt-get -y install \
      sudo \
      cron \
      apache2 \
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
      php5-memcache\
      php5-xdebug \
      apt-utils \
      debconf-utils
RUN echo "mysql-server-5.5 mysql-server/root_password password mahara" | debconf-set-selections
RUN echo "mysql-server-5.5 mysql-server/root_password_again password mahara" | debconf-set-selections
RUN apt-get -y install mysql-server
RUN apt-get clean

COPY ./apache2/default /etc/apache2/sites-available/
COPY run /usr/local/bin/
RUN chmod +x /usr/local/bin/run
RUN a2enmod rewrite

EXPOSE 80

CMD ["/usr/local/bin/run"]
