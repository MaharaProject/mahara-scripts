FROM ubuntu:14.04
MAINTAINER "Aaron Wells <aaronw@catalyst.net.nz>"

# --build-arg to include build-time variables?

# Install needed software
RUN apt-get update && apt-get install -y \
    firefox \
    git \
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
    xvfb \
&& rm -rf /var/lib/apt/lists/*
RUN npm install -g gulp

# TODO: fold these into the above
RUN apt-get update && apt-get install -y \
    supervisor \
&& rm -rf /var/lib/apt/lists/*

# Create dataroot directory
RUN mkdir -p /var/lib/mahara/dataroot
RUN chown www-data:www-data /var/lib/mahara/dataroot

# Create database users
# see https://docs.docker.com/engine/examples/postgresql_service/
USER postgres
RUN /etc/init.d/postgresql start &&\
    psql -c "CREATE ROLE maharauser PASSWORD 'kupuhipa' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN;" &&\
    createdb -O maharauser mahara

# Configure Apache
USER root
RUN sudo sh -c "echo 'post_max_size = 32M' >> /etc/php5/cli/php.ini"
RUN sudo sh -c "echo 'post_max_size = 32M' >> /etc/php5/apache2/php.ini"
RUN mkdir -p /var/www/mahara/htdocs
RUN chown -R www-data:www-data /var/www/mahara
COPY docker-apache.conf /etc/apache2/sites-available/000-default
EXPOSE 80

# Start things up
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf