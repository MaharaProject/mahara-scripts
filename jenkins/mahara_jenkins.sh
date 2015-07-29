#!/bin/bash

# Quit on error
set -e

MAXBEHIND=30
BEHATNOTNEEDED="behatnotneeded"
BEHATTESTREGEX="^test/behat/features/"

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
# Fetch the git commit ids that exist between this commit and the origin
# that exists when the patch was made.
HEAD=`git rev-parse HEAD`
the_list=`git log --pretty=format:'%H' origin/$GERRIT_BRANCH..$HEAD`
firstcommit=1
while IFS= read -r line
do
        # check if the commit or it's parents have been rejected
        php=`which php`
        outcome=`$php $HOME/mahara/mahara-scripts/jenkins/gerrit_query.php -- $line $firstcommit`
        if [ "$outcome" = "1" ]; then
            echo "The patch with git commit id $line has been rejected"
            exit 1;
        elif [ "$outcome" = "3" ]; then
            echo "The patch with git commit id $line is not the latest (current) patch"
            exit 1;
        else
            echo "The patch with git commit id $line looks ok so we will continue"
        fi
        firstcommit=0
done <<< "$the_list"

echo ""
echo "########## Check the patch contains a Behat test"
echo ""
git diff-tree --no-commit-id --name-only -r HEAD | grep $BEHATTESTREGEX > /dev/null
if [ $? = 0 ]; then
    echo "Patch includes a Behat test."
else
    echo "This patch does not include a Behat test!"
    # Check whether the commit message has "behatnotneeded" in it.
    git log -1 | grep -i $BEHATNOTNEEDED > /dev/null
    if [ $? = 0 ]; then
        echo "... but the patch is marked with \"$BEHATNOTNEEDED\", so we will continue."
    else
        echo "Please write a Behat test for it, or, if it cannot be tested, put \"$BEHATNOTNEEDED\" in its commit message."
        exit 1;
    fi
fi

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

