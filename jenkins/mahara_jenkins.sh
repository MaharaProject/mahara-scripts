#!/bin/bash

# Quit on error
set -e

MAXBEHIND=30

echo ""
echo "########## Check the patch is less than $MAXBEHIND patches behind master"
echo ""
git fetch origin master
echo ""
BEHINDBY=`git rev-list HEAD..origin/$GERRIT_BRANCH | wc -l`
echo "This patch is behind master by $BEHINDBY commit(s)"
[[ "$BEHINDBY" -lt "$MAXBEHIND" ]] || { echo "This patch is too far behind master, please rebase"; exit 1; }

echo ""
echo "########## Run make minaccept"
echo ""
make minaccept

echo ""
echo "########## Run install"
echo ""
dropdb $JOB_NAME > /dev/null 2>&1
rm -Rf $HOME/mahara/sitedata/$JOB_NAME/*
rm -Rf $HOME/mahara/sitedata/behat_$JOB_NAME/*
createdb -O jenkins -E utf8 $JOB_NAME

cd htdocs
cp $HOME/mahara/mahara-scripts/jenkins/mahara_config.php config.php
php admin/cli/install.php --adminpassword='password' --adminemail=never@example.com
cd ..

# Check if composer is not available
if [ ! -f external/composer.json ]; then
    exit 0
fi

echo ""
echo "########## Install composer"
echo ""
cd external
curl -sS https://getcomposer.org/installer | php
php composer.phar update
cd ..

echo ""
echo "########## Run unit tests"
echo ""
external/vendor/bin/phpunit htdocs/

echo ""
echo "########## Run Behat"
echo ""

test/behat/mahara_behat.sh runheadless

