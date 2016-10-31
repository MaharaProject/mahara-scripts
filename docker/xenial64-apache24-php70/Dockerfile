FROM ubuntu:16.04
MAINTAINER Son Nguyen <ngson2000@yahoo.com>

VOLUME ["/var/www/html"]
VOLUME ["/var/lib/sitedata"]

RUN apt-get update && \
    apt-get -y install \
      sudo \
      cron \
      apache2 \
      php \
      php-cli\
      curl\
      libapache2-mod-php \
      php-pgsql \
      php-mysql \
      php-gd \
      php-curl \
      php-json \
      php-xml \
      php-mbstring \
      php-ldap \
      php-memcache \
      php-xdebug && \
   apt-get clean

COPY ./apache2/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY run /usr/local/bin/
RUN chmod +x /usr/local/bin/run
RUN a2enmod rewrite

EXPOSE 80

CMD ["/usr/local/bin/run"]
