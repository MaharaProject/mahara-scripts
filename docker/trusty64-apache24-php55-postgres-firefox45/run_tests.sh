#!/bin/bash

# This script will run behat tests for mahara on a docker container

# The mahara code directory must be mapped to /var/www on the docker
MAHARAROOT=/var/www
if [ ! -f $MAHARAROOT/htdocs/index.php ]; then
  echo -e "Can not find the mahara code\n\
    Please use the option -v to map the mahara code folder which has the folder 'htdocs' on the host machine to the docker\n\
        e.g. docker run -v <path to mahara coderoot>:/var/www\n"
  exit 1;
fi

# Get action
ACTION=$1

# Wait and check if the selenium server is running in maximum 15 seconds
function is_selenium_running {
    for i in `seq 1 15`; do
        sleep 1
        res=$(curl -o /dev/null --silent --write-out '%{http_code}\n' http://localhost:4444/wd/hub/status)
        if [ $res == "200" ]; then
            return 0;
        fi
    done
    return 1;
}

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
    sudo -u www-data php htdocs/testing/frameworks/behat/cli/util.php -d
}

cd $MAHARAROOT

# Trap errors, user interrupts so we can cleanup
trap cleanup ERR
trap cleanup INT

if [ "$ACTION" = "action" ]
then

    # Wrap the util.php script

    PERFORM=$2
    sudo -u www-data php htdocs/testing/frameworks/behat/cli/util.php --$PERFORM

elif [ "$ACTION" = "run" -o "$ACTION" = 'rundebug' ]
then

    if [[ $2 == @* ]]; then
        TAGS=$2
        echo "Only run tests with the tag: $TAGS"
    elif [ $2 ]; then
        if [[ $2 == */* ]]; then
            FEATURE="test/behat/features/$2"
        else
            FEATURE=`find test/behat/features -name $2 | head -n 1`
        fi
        echo "Only run tests in file: $FEATURE"
    else
        echo "Run all tests"
    fi

    # Show behat settings to run tests on the docker
    if [ ! -d /var/lib/sitedata/behat ]; then
        echo "Create the behat dataroot folder: /var/lib/sitedata/behat"
        sudo -u www-data mkdir /var/lib/sitedata/behat;
    fi
    echo -e "Please add these settings in the file <path to mahara htdocs>/config.php to run behat tests\n\
\$cfg->behat_dbprefix  = 'behat_';\n\
\$cfg->behat_wwwroot  = 'http://localhost/';\n\
\$cfg->behat_dataroot = '/var/lib/sitedata/behat';\n"

    # Initialise the test site for behat (database, dataroot, behat yml config)
    sudo -u www-data php htdocs/testing/frameworks/behat/cli/init.php

    # Run the Behat tests themselves (after any intial setup)
    if is_selenium_running; then
        echo "Selenium is running"
    else
        echo "Start Selenium"

        SELENIUM_VERSION_MAJOR=2.53
        SELENIUM_VERSION_MINOR=1

        SELENIUM_FILENAME=selenium-server-standalone-$SELENIUM_VERSION_MAJOR.$SELENIUM_VERSION_MINOR.jar
        SELENIUM_PATH=./test/behat/$SELENIUM_FILENAME

        # If no Selenium installed, download it
        if [ ! -f $SELENIUM_PATH ]; then
            echo "Not found Selenium server in $SELENIUM_PATH"
            echo "Please download it from http://selenium-release.storage.googleapis.com/$SELENIUM_VERSION_MAJOR/$SELENIUM_FILENAME"
            exit;
        fi

        if [ $ACTION = 'run' -o $ACTION = 'rundebug' ]; then
            # Run selenium server and open Firefox in the headless mode on docker
            echo -en "Starting Xvfb ..."
            Xvfb :10 -ac > /dev/null 2>&1 & echo "PID [$!]"

            echo -en "Starting Selenium server ..."
            export DISPLAY=:10 && java -jar $SELENIUM_PATH > /dev/null 2>&1 & echo "PID [$!]"
        fi

        if is_selenium_running; then
            echo "Selenium started"
        else
            echo "Selenium can't be started"
            exit 1
        fi
    fi

    # Using docker webserver to run mahara testing site
    # Update the $MAHARAROOT/htdocs/config.php file

    BEHATCONFIGFILE=`sudo -u www-data php htdocs/testing/frameworks/behat/cli/util.php --config`
    echo "Run behat tests"


    OPTIONS=''
    if [ $ACTION = 'rundebug' ]
    then
        OPTIONS=$OPTIONS" --format=pretty"
    fi

    if [ "$TAGS" ]; then
        OPTIONS=$OPTIONS" --tags "$TAGS
    elif [ "$FEATURE" ]; then
        OPTIONS=$OPTIONS" "$FEATURE
    fi

    echo
    echo "=================================================="
    echo

    echo ./external/vendor/bin/behat --config $BEHATCONFIGFILE $OPTIONS
    sudo -u www-data ./external/vendor/bin/behat --config $BEHATCONFIGFILE $OPTIONS

    echo
    echo "=================================================="
    echo "Done behat tests!"
    echo "Clean up the testing site"
    cleanup 0
else
    # Help text if we got an unexpected (or empty) first param
    SCRIPTNAME=`basename "$0"`
    echo "Expected something like one of the following:"
    echo
    echo "# Run all tests:"
    echo "$SCRIPTNAME run"
    echo ""
    echo "# Run tests in file \"example.feature\""
    echo "$SCRIPTNAME run example.feature"
    echo ""
    echo "# Run tests with specific tag:"
    echo "$SCRIPTNAME run @tagname"
    echo ""
    echo "# Run tests with extra debug output:"
    echo "$SCRIPTNAME rundebug"
    echo "$SCRIPTNAME rundebug example.feature"
    echo "$SCRIPTNAME rundebug @tagname"
    echo ""
    echo "# Enable test site:"
    echo "$SCRIPTNAME action enable"
    echo ""
    echo "# Disable test site:"
    echo "$SCRIPTNAME action disable"
    echo ""
    echo "# List other actions you can perform:"
    echo "$SCRIPTNAME action help"
    exit 1
fi

