#!/bin/bash

# This script will clean up behat test environment on the given docker
# if the running tests is stopped by user

function cleanup {
    echo "Shutdown Selenium"
    curl -o /dev/null --silent http://localhost:4444/selenium-server/driver/?cmd=shutDownSeleniumServer

    if [[ $1 ]]
    then
        exit $1
    else
        exit 255
    fi

    echo "Disable behat test environment"
    php /var/www/htdocs/testing/frameworks/behat/cli/util.php -d
}

cleanup 0

