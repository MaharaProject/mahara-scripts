#!/bin/bash
set -e

# This will launch a mahara site on a docker container
# Mahara code and dataroot must be mapped from the host machine
if [ $# -lt 4 ]; then
  echo -e "Launch a mahara site on the docker container\n\
\n\
        Usage: $0 <nameofcontainer> <port> <pathtomaharacode> <pathtomaharadataroot> [<docker image>] \n\
        For example: $0 maharasite01 8080 /home/user/code/mahara /home/user/maharadataroot\n\
        You can then access the mahara site via http://localhost:8080/ on the host machine\n\
\n\
        The default docker image is 'cat-prod-dockerregistry.catalyst.net.nz/sonn/mahara-dev:trusty64-apache24-php55-postgres-firefox45'\n"
  exit 1;
fi

# Usage: ensure_webserver_running <url>
function ensure_webserver_running {
    for i in `seq 1 15`; do
        sleep 1
        if curl --output /dev/null --silent --head --fail "$1"; then
            return 0;
        fi
    done
    return 1;
}

CONTAINERNAME=$1
PORT=$2
CODEROOT=$3
DATAROOT=$4
DOCKERIMAGE="cat-prod-dockerregistry.catalyst.net.nz/sonn/mahara-dev:trusty64-apache24-php55-postgres-firefox45"
if [ -n "$5" ]; then
  echo -en "Checking if the docker image '$5' is available ..."
  if [[ "$(sudo docker images -q $5 2> /dev/null)" == "" ]]; then
    echo "FAILED"
  else
    DOCKERIMAGE=$5
    echo "OK"
  fi
fi
echo "The docker image '$DOCKERIMAGE' will be used"

# Check we are not running as root for some weird reason
if [[ "$USER" = "root" ]]; then
  echo "This script should not be run as root"
  exit 1
fi

DOCKEROPTIONS=""

CONTAINERID=`sudo docker ps -a -f name=$CONTAINERNAME -q`
if [ "$CONTAINERID" != "" ]; then
  if [[ "$(sudo docker ps -f name=$CONTAINERNAME -q)" != "" ]]; then
    echo -e "FAILED\n\
    The container '$CONTAINERNAME' is running\n\
    Run: stop_mahara_container.sh $CONTAINERNAME to stop it\n"
    exit 2
  else
    sudo docker rm $CONTAINERID > /dev/null 2>&1
  fi
fi
DOCKEROPTIONS="$DOCKEROPTIONS --name $CONTAINERNAME"

echo -en "Checking if $PORT is in use ..."
if sudo netstat -an | grep "$PORT" | grep "LISTEN" > /dev/null 2>&1; then
  echo -e "FAILED\n\
  The port '$PORT' is already in use by another application\n"
  exit 2
fi
DOCKEROPTIONS="$DOCKEROPTIONS -p $PORT:80"
echo "OK"

echo -en "Checking mahara code ..."
if sudo -u www-data test -r $CODEROOT/htdocs/index.php; then
  echo "OK"
  DOCKEROPTIONS="$DOCKEROPTIONS -v $CODEROOT:/var/www:ro"
  if [ ! -f $CODEROOT/htdocs/theme/raw/style/style.css ]; then
    echo "Generate CSS files for themes and install other required software"
    make -C $CODEROOT all
  fi
  if [ ! -f $CODEROOT/external/composer.lock ]; then
    echo "Install/Update PHP Composer and all other required software"
    make -C $CODEROOT initcomposer
  fi
  SELENIUM_VERSION_MAJOR=2.53
  SELENIUM_VERSION_MINOR=1
  SELENIUM_FILENAME=selenium-server-standalone-$SELENIUM_VERSION_MAJOR.$SELENIUM_VERSION_MINOR.jar
  SELENIUM_PATH=$CODEROOT/test/behat/$SELENIUM_FILENAME
  if [ ! -f $SELENIUM_PATH ]; then
    echo -en "Downloading Selenium server ..."
    wget -q -O $SELENIUM_PATH http://selenium-release.storage.googleapis.com/$SELENIUM_VERSION_MAJOR/$SELENIUM_FILENAME
    echo "Done"
  fi
else
  echo -e "FAILED\n\
  Can not read the mahara code\n\
    Please make sure the directory '$CODEROOT' containing the mahara directory 'htdocs' and readable by user 'www-data'\n"
  exit 3
fi

echo -en "Checking mahara dataroot ..."
if sudo -u www-data test -w $DATAROOT; then
  DOCKEROPTIONS="$DOCKEROPTIONS -v $DATAROOT:/var/lib/sitedata"
  echo "OK"
else
  echo -e "FAILED\n\
  Can not read and write the mahara dataroot '$DATAROOT'\n\
    Please make sure the directory '$DATAROOT' writable by user 'www-data'\n"
  exit 4
fi

echo -en "Starting the container ..."
sudo docker run -d $DOCKEROPTIONS $DOCKERIMAGE run $PORT > /dev/null 2>&1
# Wait until the site is available
ensure_webserver_running http://localhost:$PORT/
echo "Done"

echo "You can now access the mahara site at http://localhost:$PORT/"
