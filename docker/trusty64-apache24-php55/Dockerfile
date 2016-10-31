FROM ubuntu:14.04
MAINTAINER Son Nguyen <ngson2000@yahoo.com>

VOLUME ["/var/www/html"]
VOLUME ["/var/lib/sitedata"]

RUN apt-get update && \
    apt-get -y install \
      sendmail \
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
      php5-xdebug && \
   apt-get clean

COPY ./apache2/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY run /usr/local/bin/
RUN chmod +x /usr/local/bin/run
RUN a2enmod rewrite

EXPOSE 80

CMD ["/usr/local/bin/run"]
