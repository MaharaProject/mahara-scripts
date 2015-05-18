#!/bin/bash

# Quit on error
set -e

MAXBEHIND=30

echo ""
echo "########## Check the patch is less than $MAXBEHIND patches behind remote branch HEAD"
echo ""
git fetch origin $GERRIT_BRANCH
echo ""
BEHINDBY=`git rev-list HEAD..origin/$GERRIT_BRANCH | wc -l`
echo "This patch is behind $GERRIT_BRANCH by $BEHINDBY commit(s)"
[[ "$BEHINDBY" -lt "$MAXBEHIND" ]] || { echo "This patch is too far behind master, please rebase"; exit 1; }

echo "########## Check the patch and its parents are not already rejected"
echo ""
# Fetch the last 30 git commit ids and check the ones that are not also present in origin
# This allows us to check the current patch and it's parents all the way back to a commit
# that exists in origin, ie the point that origin HEAD was at when the patch was made. If
# there are more than 30 steps to get to origin HEAD the check above will handle that.
HEAD=`git rev-parse HEAD`
the_list=`git log --pretty=format:'%H' origin/$GERRIT_BRANCH..$HEAD`
while IFS= read -r line
do
        # check if the commit or it's parents have been rejected
        php=`which php`
        outcome=`$php $HOME/mahara/mahara-scripts/jenkins/gerrit_query.php -- $line`
        if [ "$outcome" = "1" ]; then
            echo "The patch with git commit id $line has been rejected"
            exit 1;
        else
            echo "The patch with git commit id $line looks ok so we will continue"
        fi
done <<< "$the_list"

echo ""
echo "########## Run make minaccept"
echo ""
make minaccept

echo ""
echo "########## Run install"
echo ""
dropdb $JOB_NAME
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

