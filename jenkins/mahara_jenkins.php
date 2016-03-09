#!/usr/bin/php
<?php
/**
 * This is the script that Jenkins executes to run the tests.
 * If it exits with a status of "0" (success) then Jenkins counts
 * the test as a success.
 *
 * If it exits with a non-0 status, Jenkins count the test as
 * a failure.
 *
 * (Specifically, in the "mahara-gerrit" project on our Jenkins
 * server, the one and only build step is to update the
 * mahara-scripts project and then execute this command.)
 */

/**
 * Environment variables passed to us by Jenkins.
 * This is not an exhaustive list, just the ones we're currently using.
 * For a list of variables provided by Jenkins see:
 *    http://test.mahara.org/env-vars.html/
*  For a list of variables provided by the Gerrit Trigger plugin see
*     http://test.mahara.org/plugin/gerrit-trigger/help-whatIsGerritTrigger.html
*  For a list of variables provided by the Git plugin see
*     https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin#GitPlugin-Environmentvariables
 */
$GERRIT_REFSPEC = getenv('GERRIT_REFSPEC');
$GERRIT_BRANCH = getenv('GERRIT_BRANCH');
$JOB_NAME = getenv('JOB_NAME');
$HOME = getenv('HOME');

/**
 * Configuration variables
 */
// If a commit is more than $MAXBEHIND commits behind the current tip of the branch, we require
// it to be rebased before running the tests.
$MAXBEHIND = 30;
// The string to look for in commit messages to indicate that it's okay the commit contains no
// new Behat tests.
$BEHATNOTNEEDED = "behatnotneeded";
// The regex we use to check for whether a commit includes new Behat tests (any changes to files)
// that match this regex)
$BEHATTESTREGEX = "^test/behat/features/";

echo "\n";
echo "########## Check the patch is less than $MAXBEHIND patches behind remote branch HEAD\n";
echo "\n";
passthru_or_die("git fetch origin $GERRIT_BRANCH");
echo "";
$behindby = shell_exec_or_die("git rev-list HEAD..origin/$GERRIT_BRANCH | wc -l");
echo "This patch is behind $GERRIT_BRANCH by $behindby commit(s)\n";
if ($behindby > $MAXBEHIND) {
    echo "This patch is too far behind master, please rebase\n";
    exit(1);
}

echo "########## Check the patch and its parents are not already rejected\n";
echo "\n";

# Fetch the git commit ids that exist between this commit and the origin
# that exists when the patch was made.
$headcommithash = shell_exec_or_die("git rev-parse HEAD");
exec_or_die("git log --pretty=format:'%H' origin/$GERRIT_BRANCH..$headcommithash", $commitancestors);
if (empty($commitancestors)) {
    // No ancestors means this commit is the head of the branch, or is an ancestor of the branch.
    // In which case... well, it's not really either a pass or a failure. But a pass makes more sense.
    echo "Patch already merged\n";
    exit(0);
}
$firstcommit = true;
$i = 0;

$trustedusers = array();
foreach ($commitancestors as $commit) {
    $commit = trim($commit);

    $content = gerrit_query('/changes/?q=commit:' . $commit . '+branch:' . $GERRIT_BRANCH . '&o=LABELS&o=CURRENT_REVISION&pp=0');
    // Because we queried by commit and branch, should return exactly one record.
    $content = $content[0];

    // Doublecheck to see if this has already been merged
    if ($content->status == 'MERGED') {
        // If this commit has been merged, then there's no reason to check it or any earlier ones.
        break;
    }

    $myurl = 'https://reviews.mahara.org/' . $content->_number;

    // Check that the patch we are testing is the latest (current) patchset in series
    if ($content->current_revision != $commit) {
        if ($firstcommit) {
            echo "This patch is not the latest (current) patch in its Gerrit change set";
        }
        else {
            echo "This patch is descended from a patch that is not the latest (current) patch in its Gerrit change set: $myurl\n";
        }
        exit(1);
    }

    if ($content->status == 'ABANDONED') {
        if ($firstcommit) {
            echo "This patch has been abandoned.\n";
        }
        else {
            echo "This patch is descended from abandoned Gerrit patch: $myurl\n";
        }
        exit(1);
    }

    if (!empty($content->labels->{'Verified'}->rejected)) {
        if ($firstcommit) {
            echo "This patch has failed manual testing.\n";
        } else {
            echo "This patch is descended from a patch that has failed manual testing: $myurl\n";
        }
        exit(1);
    }

    if (!empty($content->labels->{'Code-Review'}->rejected)) {
        if ($firstcommit) {
            echo "This patch has failed code review.\n";
        } else {
            echo "This patch is descended from a patch that has failed code review: $myurl\n";
        }
        exit(1);
    }

    if (!$firstcommit && !empty($content->labels->{'Automated-Tests'}->rejected)) {
        echo "This patch is descended from a patch that has failed automated testing: $myurl\n";
        exit(1);
    }

    // To prevent attackers from using our Jenkins to execute arbitrary unsafe code, reject any
    // code that was uploaded by someone who has not been manually added to the Mahara Reviewers
    // or Mahara Testers group. Or if the code has a +2 code review, then it's also okay to run.
    $uploader = $content->revisions->{$commit}->uploader->_account_id;

    // Cacheing the list of trusted users to reduce the number of queries we have to make.
    if (!array_key_exists($uploader, $trustedusers)) {
        // Assume we don't trust them, until we find that they belong to a trusted group.
        $trustedusers[$uploader] = false;

        // (note that because we're not authenticating, this will only return their membership
        // in groups that are set to make their list of members public)
        $groups = gerrit_query('/accounts/' . $uploader . '/groups/?pp=0');
        foreach ($groups as $group) {
            if ($group->owner == 'Mahara Reviewers' || $group->owner == 'Mahara Testers') {
                $trustedusers[$uploader] = true;
            }
        }
    }

    // If they're not a trusted user, then only run their code if it has passed code review.
    if (!$trustedusers[$uploader]) {
        if (empty($content->labels->{'Code-Review'}->approved)) {
            if ($firstcommit) {
                echo "This patch was uploaded by an unvetted user in Gerrit.\n";
            }
            else {
                echo "This patch is descended from a patch that was uploaded by an unvetted user in Gerrit: $myurl\n";
            }
            echo "For security purposes, it needs to be code reviewed before it is put through automated testing.\n";
            exit(1);
        }
        else {
            echo "Commit {$commit} was uploaded by an unvetted user in Gerrit, however it has passed code review, so it is assumed safe for automated testing.\n";
        }
    }

    // SUCCESS!
    if ($firstcommit) {
        echo "$i. This patch is ready for automated testing, so we will continue\n";
    }
    else {
        echo "$i. Ancestor patch with git commit id $commit looks ok so we will continue\n";
    }
    $firstcommit = false;
    $i++;
}

echo "\n";
echo "########## Run make minaccept\n";
echo "\n";
passthru_or_die("make minaccept");

echo "\n";
echo "########## Run install\n";
echo "\n";
passthru("dropdb $JOB_NAME");
passthru_or_die("rm -Rf $HOME/mahara/sitedata/$JOB_NAME/*");
passthru_or_die("rm -Rf $HOME/mahara/sitedata/behat_$JOB_NAME/*");
passthru_or_die("createdb -O jenkins -E utf8 $JOB_NAME");

chdir('htdocs');
passthru_or_die("cp $HOME/mahara/mahara-scripts/jenkins/mahara_config.php config.php");
passthru_or_die(PHP_BINARY . " admin/cli/install.php --adminpassword='password' --adminemail=never@example.com");
chdir('..');

# Check if composer is not available
if (!file_exists("external/composer.json")) {
    exit(0);
}

echo "\n";
echo "########## Install composer\n";
echo "\n";
chdir('external');
passthru_or_die("curl -sS https://getcomposer.org/installer | php");
passthru_or_die(PHP_BINARY . ' composer.phar update');
chdir('..');

echo "\n";
echo "########## Run unit tests\n";
echo "\n";
passthru_or_die('external/vendor/bin/phpunit htdocs/');

echo "\n";
echo "########## Verify that the patch contains a Behat test\n";
echo "\n";
if (trim(shell_exec("git diff-tree --no-commit-id --name-only -r HEAD | grep -c $BEHATTESTREGEX")) >= 1) {
    echo "Patch includes a Behat test.\n";
}
else {
    echo "This patch does not include a Behat test!\n";
    # Check whether the commit message has "behatnotneeded" in it.
    if (trim(shell_exec("git log -1 | grep -i -c $BEHATNOTNEEDED")) >= 1) {
        echo "... but the patch is marked with \"$BEHATNOTNEEDED\", so we will continue.\n";
    }
    else {
        echo "Please write a Behat test for it, or, if it cannot be tested, put \"$BEHATNOTNEEDED\" in its commit message.\n";
        exit(1);
    }
}

echo "\n";
echo "########## Build & Minify CSS\n";
echo "\n";
passthru_or_die('make');

echo "\n";
echo "########## Run Behat\n";
echo "\n";

passthru_or_die('test/behat/mahara_behat.sh runheadless');

exit(0);


///////////////////////////////////// FUNCTIONS ///////////////////////////////////////
/**
 * Call this function to do passthru(), but die if the command that was being
 * invoked exited with a non-success return value.
 *
 * @param string $command
 */
function passthru_or_die($command, &$return_var = null) {
    passthru($command, $return_var);
    if ($return_var !== 0) {
        log_and_die($command, $return_var);
    }
}

/**
 * Call this function to do exec() but die if the command errored out.
 * @param unknown $command
 */
function exec_or_die($command, &$output = null, &$return_var = null) {
    $returnstring = exec($command, $output, $return_var);
    if ($return_var !== 0) {
        log_and_die($command, $return_var);
    }

    return $returnstring;
}


/**
 * This function emulates shellexec(), but dies if the command that was being
 * invoked exited with a non-success exit value.
 *
 * Because it calls exec() on the backend, it also has the side effect of
 * trimming whitespace from the return value (unlike shellexec(), which normally
 * includes the ending "\n" on the output)
 *
 * @param unknown $command
 */
function shell_exec_or_die($command) {
    // shellexec() doesn't normally give you access to the command's exit code,
    // so we instead will call exec()
    exec_or_die($command, $output);

    return implode("\n", $output);
}


/**
 * Call this method to die after a bad command. It prints an error message
 * about the command that failed, and then exits with status code 1.
 * @param string $commandtolog The command to log a message about
 * @param integer $itsreturnvar The return value of that command
 */
function log_and_die($commandtolog, $itsreturnvar) {
    echo "\nEXITING WITH FAILURE\n";
    echo "ERROR: Return value of '$itsreturnvar' on this command:\n";
    echo "$commandtolog\n";
    echo "\n";
    debug_print_backtrace();
    echo "\n";
    exit(1);
}


/**
 * Make an unauthenticated request to gerrit's REST service.
 *
 * @param string $relurl The relative URL of the REST service. URL query component should include 'pp=0'
 */
function gerrit_query($relurl) {
    $ch = curl_init();
    if ($relurl[0] !== '/') {
        $relurl = '/' . $relurl;
    }
    curl_setopt($ch, CURLOPT_URL, 'https://reviews.mahara.org' . $relurl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    $content = curl_exec($ch);
    curl_close($ch);
    // We need to fetch the json line from the result
    $content = explode("\n", $content);
    return json_decode($content[1]);
}