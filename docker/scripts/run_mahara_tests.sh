#!/bin/bash
set -e
# This script will run behat tests for mahara on a given docker container

if [ $# -lt 2 ]; then
  echo -e "Run behat tests for mahara on a given docker container\n\
    Usage: $0 <container name> <action> [tag name|feature file]\n\
    For example: $0 mahara_container01 run\n\
       Run all behat tests on the container: mahara_container01"
fi

function cleanup {
  sudo docker exec $CONTAINERNAME run_cleanup.sh
}

CONTAINERNAME=$1
echo -en "Checking if $CONTAINERNAME is running ..."
if [[ "$(sudo docker ps -q -f name=$CONTAINERNAME)" = "" ]]; then
  echo -e "FAILED\n\
  The container '$CONTAINERNAME' is not running\n"
  exit 1
fi
echo "OK"

# Run the behat tests
shift
sudo docker exec -it $CONTAINERNAME run_tests.sh $*

#cleanup
exit 0

# Trap errors, user interrupts so we can cleanup
#trap cleanup ERR
#trap cleanup INT

