FROM ubuntu:14.04
MAINTAINER "Aaron Wells <aaronw@catalyst.net.nz>"

COPY catalyst.sources.list /etc/apt/sources.list

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
# (from https://github.com/docker-library/postgres/blob/04b1d366d51a942b88fff6c62943f92c7c38d9b6/9.3/Dockerfile )
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && update-locale LANG=en_US.utf8
ENV LANG en_US.utf8
ENV LOCALE en_US.UTF-8

# Install needed software
RUN apt-get update && apt-get install -y \
    curl \
    firefox \
    git \
    haveged \
    libapache2-mod-php5 \
    postgresql \
    php5-cli \
    php5-curl \
    php5-gd \
    php5-json \
    php5-ldap \
    php5-pgsql \
    php5-xmlrpc \
    nodejs-legacy \
    npm \
    openjdk-7-jre \
    supervisor \
    wget \
    xvfb \
&& rm -rf /var/lib/apt/lists/*

RUN npm install -g gulp

# Create dataroot directory
RUN mkdir -p /var/lib/dataroot/mahara
RUN chown -R www-data:www-data /var/lib/dataroot/mahara

# Create database users
# see https://docs.docker.com/engine/examples/postgresql_service/
USER postgres
RUN /etc/init.d/postgresql start &&\
    psql -c "CREATE ROLE maharauser PASSWORD 'kupuhipa' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN;" &&\
    createdb -E UTF8 -O maharauser mahara

# Configure Apache
USER root
RUN sudo sh -c "echo 'post_max_size = 32M' >> /etc/php5/cli/php.ini"
RUN sudo sh -c "echo 'post_max_size = 32M' >> /etc/php5/apache2/php.ini"
RUN mkdir -p /var/www/mahara
RUN chown -R www-data:www-data /var/www/mahara
COPY docker-apache.conf /etc/apache2/sites-available/000-default
EXPOSE 80

# Start things up
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf