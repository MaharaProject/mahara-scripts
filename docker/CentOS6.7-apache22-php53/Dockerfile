FROM centos:6.7
MAINTAINER http://www.centos.org
LABEL Vendor="CentOS"
LABEL License=GPLv2

RUN yum -y update && yum clean all
RUN yum -y install httpd mod_ssl\
      php\
      php-cli\
      curl\
      php-pgsql \
      php-mysql \
      php-gd \
      php-curl \
      php-xml \
 && yum clean all

EXPOSE 80

# Simple startup script to avoid some issues observed with container restart 
ADD run-httpd.sh /run-httpd.sh
RUN chmod -v +x /run-httpd.sh

CMD ["/run-httpd.sh"]
