#!/bin/bash
set -e
# This script will stop the given mahara container

if [ $# -ne 1 ]; then
  echo -e "Stop the given mahara container\n\
    Usage: $0 <container name>\n\
    For example: $0 mahara_container01\n\
       Stop the container: mahara_container01"
fi

CONTAINERNAME=$1
echo -en "Checking if $CONTAINERNAME is running ..."
if [[ "$(sudo docker ps -q -f name=$CONTAINERNAME)" = "" ]]; then
  echo -e "FAILED\n\
  The container '$CONTAINERNAME' is not running\n"
  exit 1
fi
echo "OK"

# Stop the container
echo -en "Stopping the container $CONTAINERNAME ..."
sudo docker stop $CONTAINERNAME > /dev/null 2>&1
echo "Done"


