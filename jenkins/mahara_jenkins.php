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
if ($behindby < $MAXBEHIND) {
    echo "This patch is too far behind master, please rebase\n";
    exit(1);
}

echo "########## Check the patch and its parents are not already rejected\n";
echo "\n";

# Fetch the git commit ids that exist between this commit and the origin
# that exists when the patch was made.
$headcommithash = shell_exec_or_die("git rev-parse HEAD");
exec_or_die("git log --pretty=format:'%H' origin/$GERRIT_BRANCH..$headcommithash", $the_list);
$firstcommit = 1;

foreach ($the_list as $line) {
    $line = trim($line);
    if (empty($line)) {
        echo "Patch already merged\n";
        exit(1);
    }

    # check if the commit or it's parents have been rejected
    $outcome = shell_exec_or_die(PHP_BINARY . " $HOME/mahara/mahara-scripts/jenkins/gerrit_query.php -- $line $firstcommit");
    switch ($outcome) {
        case 1:
            echo "The patch with git commit id $line has been rejected\n";
            exit(1);
            break;
        case 3:
            echo "The patch with git commit id $line is not the latest (current) patch\n";
            exit(1);
            break;
        case 4:
            echo "This patch or a parent patch has been abandoned\n";
            exit(1);
            break;
        default:
            echo "The patch with git commit id $line looks ok so we will continue\n";
    }
    $firstcommit = 0;
}

echo "\n";
echo "########## Check the patch contains a Behat test\n";
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
echo "########## Run make minaccept\n";
echo "\n";
passthru_or_die("make minaccept");

echo "\n";
echo "########## Run install\n";
echo "\n";
passthru("dropdb $JOB_NAME");
passthru_or_die("rm -Rf $HOME/mahara/sitedata/$JOB_NAME/*");
passthru_or_die("rm -Rf $HOME/mahara/sitedata/behat_$JOB_NAME/*");
//passthru_or_die("createdb -O jenkins -E utf8 $JOB_NAME");
passthru_or_die("createdb -E utf8 $JOB_NAME");

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