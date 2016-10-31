FROM ubuntu:14.04
MAINTAINER Son Nguyen <son.nguyen@catalyst.net.nz>

# trusty64, Apache 2.4, Php 5.5, PostgreSQL 9.3, Xvfb, Firefox 45
# This will be used for running behat tests

VOLUME ["/var/www"]
VOLUME ["/var/lib/sitedata"]

RUN apt-get update && \
    apt-get -y install software-properties-common

RUN add-apt-repository universe

RUN apt-get update && \
    apt-get -y install \
      sudo \
      sendmail \
      memcached \
      cron \
      curl\
      apache2\
      php5 \
      php5-cli\
      libapache2-mod-php5\
      php5-pgsql \
      php5-pgsql \
      php5-gd \
      php5-curl \
      php5-json \
      php5-ldap \
      php5-xmlrpc \
      php5-mcrypt \
      php5-memcache\
      php5-xdebug\
      php5-mysql

RUN apt-get -y install postgresql postgresql-contrib

RUN apt-get -y install openjdk-7-jre xvfb
RUN apt-get clean

# Install Firefox 45.0.2 64bit
ADD firefox-45.0.2.tar.bz2 /usr/local/
RUN ln -s /usr/local/firefox/firefox /usr/bin/firefox

RUN rm -rf /var/www/html
ADD run* /usr/local/bin/
RUN chmod +x /usr/local/bin/run*

EXPOSE 80
