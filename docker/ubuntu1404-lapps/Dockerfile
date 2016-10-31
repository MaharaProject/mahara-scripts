FROM ubuntu:14.04
MAINTAINER Son Nguyen <son.nguyen@catalyst.net.nz>
# Ubuntu 14.04, Apache 2.4, Php 5.5, PostgreSQL 9.3, Elastic search

VOLUME ["/var/www/html"]
VOLUME ["/var/lib/sitedata"]

RUN add-apt-repository universe && \
    apt-get update && \
    apt-get -y install \
      sudo \
      sendmail \
      memcached \
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
      php5-mcrypt \
      php5-memcache\
      php5-xdebug
RUN apt-get -y install postgresql postgresql-contrib

RUN apt-get -y install openjdk-7-jre
RUN apt-get clean

COPY ./elasticsearch/elasticsearch-1.5.2.deb /tmp
RUN dpkg -i /tmp/elasticsearch-1.5.2.deb


COPY ./apache2/000-default.conf /etc/apache2/sites-available/
COPY run /usr/local/bin/
RUN chmod +x /usr/local/bin/run
RUN a2enmod rewrite

EXPOSE 80

CMD ["/usr/local/bin/run"]
