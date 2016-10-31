FROM ubuntu:14.04
MAINTAINER Son Nguyen <ngson2000@yahoo.com>

RUN apt-get update && \
    apt-get -y install \
      sudo \
      cron \
      gzip \
      apache2 \
      php5 \
      php5-cli\
      curl\
      git\
      bzr\
      libhtml-tiny-perl\
      liblocale-po-perl\
      libwww-perl && \
   apt-get clean

EXPOSE 80

